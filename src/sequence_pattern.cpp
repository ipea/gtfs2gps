// Ported from gtfstools (src/sequence_pattern.cpp, development version after
// 2.0.0, commit 99dc38b, by Rafael H. M. Pereira; MIT license, copyright Ipea,
// the same license and copyright holder as gtfs2gps). Used by feed_to_gps() to
// group trips by stop pattern without pasting text keys.

#include <cstddef>
#include <cstdint>
#include <unordered_map>
#include <vector>

#include <cpp11.hpp>
using namespace cpp11;

// identifies groups of rows (e.g. the stop times of each trip) that hold the
// same sequence of values. groups are compared as whole slices, so, unlike keys
// built by pasting values together, no separator can make two different
// sequences look the same. NA_integer_ is compared as any other value

namespace {

// mixes the bits of a 64-bit value (the splitmix64 finalizer), so that slices
// with similar values get very different hashes

inline std::uint64_t mix_bits(std::uint64_t x) {
  x ^= x >> 30;
  x *= 0xbf58476d1ce4e5b9ULL;
  x ^= x >> 27;
  x *= 0x94d049bb133111ebULL;
  x ^= x >> 31;
  return x;
}

// groups are stored in the hash map by their index. the hash of each group is
// calculated beforehand, and two groups are equal if they have the same size
// and the same values in every column

struct GroupHash {
  const std::vector<std::uint64_t>* hash;

  std::size_t operator()(R_xlen_t group) const {
    return static_cast<std::size_t>((*hash)[group]);
  }
};

struct GroupEqual {
  const std::vector<R_xlen_t>* start;
  const std::vector<int>* size;
  const std::vector<const int*>* values;

  bool operator()(R_xlen_t a, R_xlen_t b) const {
    const int n = (*size)[a];
    if (n != (*size)[b]) return false;

    for (const int* column : *values) {
      const int* first_a = column + (*start)[a];
      const int* first_b = column + (*start)[b];
      for (int r = 0; r < n; r++) {
        if (first_a[r] != first_b[r]) return false;
      }
    }

    return true;
  }
};

} // namespace

//' cpp_sequence_pattern_id
//'
//' Assigns an id to each group of rows, so that groups holding the same values
//' get the same id. 'group_size' holds the number of rows of each group, whose
//' rows are contiguous and follow the order of 'group_size'. 'columns' is a
//' list of integer vectors whose lengths are the total number of rows. Ids are
//' numbered in order of first appearance.
//'
//' @noRd
[[cpp11::register]]
integers cpp_sequence_pattern_id(const integers group_size,
                                 const list columns) {
  const R_xlen_t n_groups = group_size.size();
  const R_xlen_t n_columns = columns.size();

  if (n_columns == 0) {
    stop("'columns' must include at least one vector.");
  }

  std::vector<R_xlen_t> start(static_cast<std::size_t>(n_groups));
  std::vector<int> size(static_cast<std::size_t>(n_groups));
  R_xlen_t n_rows = 0;

  for (R_xlen_t i = 0; i < n_groups; i++) {
    const int n = group_size[i];

    // NA_integer_ is the smallest int, so it's caught here too

    if (n < 0) stop("'group_size' must not include negative or NA values.");
    start[i] = n_rows;
    size[i] = n;
    n_rows += n;
  }

  // the data pointer of each column is read only once, because accessing
  // ALTREP vectors element by element is slow

  std::vector<const int*> values(static_cast<std::size_t>(n_columns));

  for (R_xlen_t k = 0; k < n_columns; k++) {
    SEXP column = columns[k];

    if (TYPEOF(column) != INTSXP) {
      stop("Every element of 'columns' must be an integer vector.");
    }
    if (Rf_xlength(column) != n_rows) {
      stop("Every element of 'columns' must have sum(group_size) elements.");
    }

    values[k] = INTEGER_RO(column);
  }

  std::vector<std::uint64_t> hash(static_cast<std::size_t>(n_groups));

  for (R_xlen_t i = 0; i < n_groups; i++) {
    std::uint64_t h = mix_bits(static_cast<std::uint64_t>(size[i]));
    for (const int* column : values) {
      const int* first = column + start[i];
      for (int r = 0; r < size[i]; r++) {
        h = mix_bits(h + static_cast<std::uint32_t>(first[r]));
      }
    }
    hash[i] = h;
  }

  std::unordered_map<R_xlen_t, int, GroupHash, GroupEqual> first_group(
    static_cast<std::size_t>(n_groups),
    GroupHash{&hash},
    GroupEqual{&start, &size, &values}
  );

  writable::integers result(n_groups);
  int next_id = 1;

  for (R_xlen_t i = 0; i < n_groups; i++) {
    const auto inserted = first_group.emplace(i, next_id);
    if (inserted.second) next_id++;
    result[i] = inserted.first->second;
  }

  return result;
}
