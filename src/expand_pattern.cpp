#include <cpp11.hpp>
#include <climits>
#include <cmath>
#include <cstddef>
#include <unordered_map>
#include <vector>
using namespace cpp11;

// Expands every trip of a stop pattern into GPS points, as update_dt() (now in
// tests/testthat/helper-update-dt.R) does for one trip. Each step reproduces the
// R code exactly, so that the output is identical():
// - the trip's times are joined to the template by stop_sequence, the last match
//   winning and NA matching NA, as match() on the reversed stop_sequence;
// - each timed stop gets an extra row before it, at its arrival_time, with the
//   original dist; the stop row itself gets dist 0;
// - times are wrapped at midnight as as.ITime() does (x %% 86400);
// - each segment's cumulative time restarts from the stored cumtime of its first
//   point and is summed in long double, as R's cumsum() does (in double on builds
//   of R without long double, as R does there);
// - round() is nearbyint() and as.integer() truncates, NaN giving NA.
//
// tpl_* are the columns of the pattern's shape template (one row per point);
// the stop_times of the trips are contiguous, in the order of trip_size.
// Returns the rows of all converted trips, concatenated, and the status of each
// trip: 0 converted, 1 skipped (less than two departure times), 2 failed (less
// than two timed stop rows on the shape, which errors in update_dt()). The
// trips after a failed one are not processed (status -1).

namespace {

struct trip_out {
  std::vector<int> src;
  std::vector<double> dist;
  std::vector<double> speed;
  std::vector<int> timestamp;
  std::vector<double> cumtime;
};

// R's x %% 86400, also for negative seconds
inline int wrap_day(int x) {
  if (x == NA_INTEGER) return NA_INTEGER;
  const int r = x % 86400;
  return r < 0 ? r + 86400 : r;
}

// R's as.integer() of a double (out of range gives NA, without R's warning)
inline int as_integer(double x) {
  if (ISNAN(x) || x >= INT_MAX + 1.0 || x <= INT_MIN) return NA_INTEGER;
  return static_cast<int>(x);
}

// 0 converted, 1 skipped, 2 failed
int expand_trip(const doubles& tpl_seq, const integers& tpl_dep, const integers& tpl_arr,
                const logicals& tpl_has_stop, const doubles& tpl_dist,
                const doubles& tpl_cumdist, const doubles& st_seq, const integers& st_dep,
                const integers& st_arr, int from, int size, bool long_double,
                trip_out& out) {
  int n_dep = 0;
  for (int j = from; j < from + size; j++) {
    if (st_dep[j] != NA_INTEGER) n_dep++;
  }
  if (n_dep < 2) return 1;

  // last row of the trip with each stop_sequence; as in match(), NA and NaN are
  // two values, each matching itself
  std::unordered_map<double, int> last_row;
  int last_na = -1, last_nan = -1;
  for (int j = from; j < from + size; j++) {
    if (R_IsNA(st_seq[j])) last_na = j;
    else if (ISNAN(st_seq[j])) last_nan = j;
    else last_row[st_seq[j]] = j;
  }

  const int n = tpl_seq.size();
  std::vector<int> dep(n), arr(n);
  for (int r = 0; r < n; r++) {
    int m = -1;
    if (R_IsNA(tpl_seq[r])) {
      m = last_na;
    } else if (ISNAN(tpl_seq[r])) {
      m = last_nan;
    } else {
      auto it = last_row.find(tpl_seq[r]);
      if (it != last_row.end()) m = it->second;
    }
    dep[r] = m < 0 ? tpl_dep[r] : st_dep[m];
    arr[r] = m < 0 ? tpl_arr[r] : st_arr[m];
  }

  // expanded rows: a timed stop row appears twice
  std::vector<int> src;
  std::vector<int> ts;
  std::vector<bool> has_stop;
  std::vector<double> dist, cd;
  src.reserve(n + size);
  for (int r = 0; r < n; r++) {
    const bool stop = tpl_has_stop[r] == TRUE;
    if (dep[r] != NA_INTEGER && stop) {
      // the extra row, at the arrival time, keeps the original dist
      src.push_back(r + 1);
      ts.push_back(wrap_day(arr[r]));
      has_stop.push_back(stop);
      dist.push_back(tpl_dist[r]);
      cd.push_back(tpl_cumdist[r]);
      // the stop row
      src.push_back(r + 1);
      ts.push_back(wrap_day(dep[r]));
      has_stop.push_back(stop);
      dist.push_back(0);
      cd.push_back(tpl_cumdist[r]);
    } else {
      src.push_back(r + 1);
      ts.push_back(wrap_day(dep[r]));
      has_stop.push_back(stop);
      dist.push_back(tpl_dist[r]);
      cd.push_back(tpl_cumdist[r]);
    }
  }

  const int n2 = src.size();
  std::vector<int> lim;
  for (int i = 0; i < n2; i++) {
    if (ts[i] != NA_INTEGER && has_stop[i]) lim.push_back(i);
  }
  if (lim.size() < 2) return 2;

  std::vector<double> spd(n2, NA_REAL), ctm(n2, 0.0);
  spd[0] = 1e-12;
  bool last_point_was_stop = false;

  for (size_t i = 0; i + 1 < lim.size(); i++) {
    const int a = lim[i];
    const int b = lim[i + 1];

    double dt = ts[b] - ts[a];
    if (dt < 0) dt += 86400; // one day in seconds

    if (a + 1 == b && !last_point_was_stop) {
      // two consecutive points with arrival_time don't need to be interpolated
      last_point_was_stop = true;
      ctm[b] = ctm[a] + dt;
      spd[b] = 1e-12;
      continue;
    }

    const double v = (cd[b] - cd[a]) / dt;
    for (int j = a; j <= b; j++) spd[j] = 3.6 * v;

    if (long_double) {
      long double sum = ctm[a];
      for (int j = a; j < b; j++) {
        sum += (cd[j + 1] - cd[j]) / v;
        ctm[j + 1] = static_cast<double>(sum);
      }
    } else {
      double sum = ctm[a];
      for (int j = a; j < b; j++) {
        sum += (cd[j + 1] - cd[j]) / v;
        ctm[j + 1] = sum;
      }
    }

    spd[a] = 1e-12;

    const double ts_a = ts[a];
    const double ctm_a = ctm[a];
    for (int j = a; j < b; j++) ts[j] = as_integer(ts_a + std::nearbyint(ctm[j] - ctm_a));
    last_point_was_stop = false;
  }

  for (int i = 0; i < n2; i++) {
    if (ISNAN(spd[i])) ctm[i] = NA_REAL;
  }

  out.src.insert(out.src.end(), src.begin(), src.end());
  out.dist.insert(out.dist.end(), dist.begin(), dist.end());
  out.speed.insert(out.speed.end(), spd.begin(), spd.end());
  out.timestamp.insert(out.timestamp.end(), ts.begin(), ts.end());
  out.cumtime.insert(out.cumtime.end(), ctm.begin(), ctm.end());
  return 0;
}

}  // namespace

[[cpp11::register]]
list cpp_expand_pattern(doubles tpl_seq, integers tpl_dep, integers tpl_arr,
                        logicals tpl_has_stop, doubles tpl_dist, doubles tpl_cumdist,
                        integers trip_size, doubles st_seq, integers st_dep,
                        integers st_arr, bool long_double) {
  const int n_trips = trip_size.size();
  writable::integers status(n_trips);
  writable::integers n_rows(n_trips);
  trip_out out;

  int from = 0;
  bool failed = false;
  for (int k = 0; k < n_trips; k++) {
    if (failed) {
      status[k] = -1;
      n_rows[k] = 0;
      continue;
    }
    const size_t before = out.src.size();
    status[k] = expand_trip(tpl_seq, tpl_dep, tpl_arr, tpl_has_stop, tpl_dist, tpl_cumdist,
                            st_seq, st_dep, st_arr, from, trip_size[k], long_double, out);
    n_rows[k] = static_cast<int>(out.src.size() - before);
    if (status[k] == 2) failed = true;
    from += trip_size[k];
  }

  return writable::list({
    "src"_nm = writable::integers(out.src.begin(), out.src.end()),
    "dist"_nm = writable::doubles(out.dist.begin(), out.dist.end()),
    "speed"_nm = writable::doubles(out.speed.begin(), out.speed.end()),
    "timestamp"_nm = writable::integers(out.timestamp.begin(), out.timestamp.end()),
    "cumtime"_nm = writable::doubles(out.cumtime.begin(), out.cumtime.end()),
    "n_rows"_nm = n_rows,
    "status"_nm = status
  });
}
