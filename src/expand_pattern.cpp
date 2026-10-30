#include <cpp11.hpp>
#include <climits>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <exception>
#include <unordered_map>
#include <vector>
using namespace cpp11;

// Expands trips into GPS points, as update_dt() (now in
// tests/testthat/helper-update-dt.R) does for one trip. Each step reproduces the
// R code exactly, so that the output is identical():
// - the trip's times are joined to its template by stop_sequence, the last match
//   winning and NA matching NA, as match() on the reversed stop_sequence;
// - each timed stop gets an extra row before it, at its arrival_time, with the
//   original dist; the stop row itself gets dist 0;
// - times are wrapped at midnight as as.ITime() does (x %% 86400);
// - each segment's cumulative time restarts from the stored cumtime of its first
//   point and is summed in long double, as R's cumsum() does (in double on builds
//   of R without long double, as R does there);
// - round() is nearbyint() and as.integer() truncates, NaN giving NA.
//
// tpl_* are the columns of the stop pattern templates (one row per shape point),
// concatenated; each trip reads its template at tpl_from (0-based), tpl_size rows.
// The stop_times of the trips are contiguous, in the order of trip_size, and the
// trips are in output order, so the rows of the converted trips come out in that
// order. Each trip gets a status: 0 converted, 1 skipped (less than two departure
// times), 2 failed (less than two timed stop rows on the shape, which errors in
// update_dt()). The caller decides what a failure means for the other trips.
//
// Two passes: the first computes each trip's status and number of rows, the
// second writes the rows of the converted trips at their offsets. Trips are
// independent and nothing is accumulated across them, so the loops can run in any
// order; inputs are read through raw pointers and nothing in the loops calls R.

namespace {

struct inputs {
  const double* tpl_seq;
  const int* tpl_dep;
  const int* tpl_arr;
  const int* tpl_has_stop;
  const double* tpl_dist;
  const double* tpl_cumdist;
  const double* st_seq;
  const int* st_dep;
  const int* st_arr;
};

struct outputs {
  int* src;
  double* dist;
  double* speed;
  int* timestamp;
  double* cumtime;
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

// the trip's departure and arrival times on each template row (the template's
// own times where the trip has no row with that stop_sequence); false when the
// trip has less than two departure times. Used by both passes.
bool join_trip(const inputs& in, int tpl_from, int n, int st_from, int size,
               std::vector<int>& dep, std::vector<int>& arr) {
  int n_dep = 0;
  for (int j = st_from; j < st_from + size; j++) {
    if (in.st_dep[j] != NA_INTEGER) n_dep++;
  }
  if (n_dep < 2) return false;

  // last row of the trip with each stop_sequence; as in match(), NA and NaN are
  // two values, each matching itself
  std::unordered_map<double, int> last_row;
  int last_na = -1, last_nan = -1;
  for (int j = st_from; j < st_from + size; j++) {
    if (R_IsNA(in.st_seq[j])) last_na = j;
    else if (ISNAN(in.st_seq[j])) last_nan = j;
    else last_row[in.st_seq[j]] = j;
  }

  dep.resize(n);
  arr.resize(n);
  for (int r = 0; r < n; r++) {
    const double seq = in.tpl_seq[tpl_from + r];
    int m = -1;
    if (R_IsNA(seq)) {
      m = last_na;
    } else if (ISNAN(seq)) {
      m = last_nan;
    } else {
      auto it = last_row.find(seq);
      if (it != last_row.end()) m = it->second;
    }
    dep[r] = m < 0 ? in.tpl_dep[tpl_from + r] : in.st_dep[m];
    arr[r] = m < 0 ? in.tpl_arr[tpl_from + r] : in.st_arr[m];
  }
  return true;
}

// pass 1: status and number of output rows of a trip, without expanding it. A
// timed stop row (non-NA departure) gives two rows; it bounds a segment once,
// plus once more when its arrival time is also known
int count_trip(const inputs& in, int tpl_from, int n, int st_from, int size,
               std::vector<int>& dep, std::vector<int>& arr, int& n_rows) {
  n_rows = 0;
  if (!join_trip(in, tpl_from, n, st_from, size, dep, arr)) return 1;
  int extra = 0, n_lim = 0;
  for (int r = 0; r < n; r++) {
    if (dep[r] != NA_INTEGER && in.tpl_has_stop[tpl_from + r] == TRUE) {
      extra++;
      n_lim += arr[r] != NA_INTEGER ? 2 : 1;
    }
  }
  if (n_lim < 2) return 2;
  n_rows = n + extra;
  return 0;
}

// pass 2: the rows of a converted trip, written from out_from; returns the number
// of rows written
int expand_trip(const inputs& in, int tpl_from, int n, int st_from, int size,
                bool long_double, std::vector<int>& dep, std::vector<int>& arr,
                const outputs& out, std::int64_t out_from) {
  join_trip(in, tpl_from, n, st_from, size, dep, arr);

  // expanded rows: a timed stop row appears twice
  std::vector<int> src;
  std::vector<int> ts;
  std::vector<bool> has_stop;
  std::vector<double> dist, cd;
  src.reserve(n + size);
  for (int r = 0; r < n; r++) {
    const int t = tpl_from + r;
    const bool stop = in.tpl_has_stop[t] == TRUE;
    if (dep[r] != NA_INTEGER && stop) {
      // the extra row, at the arrival time, keeps the original dist
      src.push_back(t + 1);
      ts.push_back(wrap_day(arr[r]));
      has_stop.push_back(stop);
      dist.push_back(in.tpl_dist[t]);
      cd.push_back(in.tpl_cumdist[t]);
      // the stop row
      src.push_back(t + 1);
      ts.push_back(wrap_day(dep[r]));
      has_stop.push_back(stop);
      dist.push_back(0);
      cd.push_back(in.tpl_cumdist[t]);
    } else {
      src.push_back(t + 1);
      ts.push_back(wrap_day(dep[r]));
      has_stop.push_back(stop);
      dist.push_back(in.tpl_dist[t]);
      cd.push_back(in.tpl_cumdist[t]);
    }
  }

  const int n2 = src.size();
  std::vector<int> lim;
  for (int i = 0; i < n2; i++) {
    if (ts[i] != NA_INTEGER && has_stop[i]) lim.push_back(i);
  }

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

  for (int i = 0; i < n2; i++) {
    const std::int64_t k = out_from + i;
    out.src[k] = src[i];
    out.dist[k] = dist[i];
    out.speed[k] = spd[i];
    out.timestamp[k] = ts[i];
    out.cumtime[k] = ctm[i];
  }
  return n2;
}

}  // namespace

[[cpp11::register]]
list cpp_expand_pattern(doubles tpl_seq, integers tpl_dep, integers tpl_arr,
                        logicals tpl_has_stop, doubles tpl_dist, doubles tpl_cumdist,
                        integers trip_tpl_from, integers trip_tpl_size, integers trip_size,
                        doubles st_seq, integers st_dep, integers st_arr,
                        bool long_double, int n_threads) {
  const int n_trips = trip_size.size();
  // raw pointers, taken here: inside the loops nothing may call R (REAL() and
  // friends also materialise ALTREP vectors)
  const inputs in = {REAL(tpl_seq), INTEGER(tpl_dep), INTEGER(tpl_arr),
                     LOGICAL(tpl_has_stop), REAL(tpl_dist), REAL(tpl_cumdist),
                     REAL(st_seq), INTEGER(st_dep), INTEGER(st_arr)};
  const int* tpl_from = INTEGER(trip_tpl_from);
  const int* tpl_size = INTEGER(trip_tpl_size);
  const int* size = INTEGER(trip_size);

  // the loops read the inputs by offset, so the offsets are checked here
  const R_xlen_t n_tpl = tpl_seq.size();
  if (tpl_dep.size() != n_tpl || tpl_arr.size() != n_tpl || tpl_has_stop.size() != n_tpl ||
      tpl_dist.size() != n_tpl || tpl_cumdist.size() != n_tpl ||
      trip_tpl_from.size() != n_trips || trip_tpl_size.size() != n_trips ||
      st_dep.size() != st_seq.size() || st_arr.size() != st_seq.size()) {
    cpp11::stop("Inputs of different lengths.");
  }
  std::vector<std::int64_t> st_from(n_trips + 1, 0);
  for (int k = 0; k < n_trips; k++) {
    if (size[k] < 0 || tpl_from[k] < 0 || tpl_size[k] < 0 ||
        static_cast<std::int64_t>(tpl_from[k]) + tpl_size[k] > n_tpl) {
      cpp11::stop("Template or stop_times offsets out of range.");
    }
    st_from[k + 1] = st_from[k] + size[k];
  }
  if (st_from[n_trips] > st_seq.size()) cpp11::stop("Template or stop_times offsets out of range.");

  writable::integers status(n_trips);
  writable::integers n_rows(n_trips);
  int* status_p = INTEGER(status);
  int* n_rows_p = INTEGER(n_rows);
  (void) n_threads;

  // each trip flags its own error (nothing is shared between trips); exceptions
  // never leave the loops
  std::vector<char> bad(n_trips, 0);
  auto any_bad = [&bad]() {
    for (char b : bad) if (b) return true;
    return false;
  };

  for (int k = 0; k < n_trips; k++) {
    try {
      std::vector<int> dep, arr;
      status_p[k] = count_trip(in, tpl_from[k], tpl_size[k],
                               static_cast<int>(st_from[k]), size[k],
                               dep, arr, n_rows_p[k]);
    } catch (...) {
      bad[k] = 1;
    }
  }
  if (any_bad()) cpp11::stop("Internal error while counting the GPS points of the trips.");

  // offsets of the converted trips in the output
  std::vector<std::int64_t> out_from(n_trips + 1, 0);
  for (int k = 0; k < n_trips; k++) {
    out_from[k + 1] = out_from[k] + (status_p[k] == 0 ? n_rows_p[k] : 0);
  }
  const std::int64_t total = out_from[n_trips];
  if (total > INT_MAX) cpp11::stop("Too many GPS points (more than %d).", INT_MAX);

  writable::integers src(total);
  writable::doubles dist(total);
  writable::doubles speed(total);
  writable::integers timestamp(total);
  writable::doubles cumtime(total);
  const outputs out = {INTEGER(src), REAL(dist), REAL(speed), INTEGER(timestamp),
                       REAL(cumtime)};

  for (int k = 0; k < n_trips; k++) {
    if (status_p[k] != 0) continue;
    try {
      std::vector<int> dep, arr;
      const int written = expand_trip(in, tpl_from[k], tpl_size[k],
                                      static_cast<int>(st_from[k]), size[k],
                                      long_double, dep, arr, out, out_from[k]);
      if (written != n_rows_p[k]) bad[k] = 1;
    } catch (...) {
      bad[k] = 1;
    }
  }
  if (any_bad()) cpp11::stop("Internal error while building the GPS points of the trips.");

  return writable::list({
    "src"_nm = src,
    "dist"_nm = dist,
    "speed"_nm = speed,
    "timestamp"_nm = timestamp,
    "cumtime"_nm = cumtime,
    "n_rows"_nm = n_rows,
    "status"_nm = status
  });
}

// whether the package was compiled with OpenMP, i.e. whether n_threads is used
[[cpp11::register]]
bool cpp_openmp_available() {
#ifdef _OPENMP
  return true;
#else
  return false;
#endif
}
