
test_that("cpp_sequence_pattern_id compares whole groups", {
  # the same cases as gtfstools' test of this function (tests/testthat/
  # test-get_stop_times_patterns.R), from which it was ported: groups 1 and 2 are
  # equal and group 3 is a prefix of them; groups 6 and 7 are equal, as NAs are
  # compared as any other value
  ids <- cpp_sequence_pattern_id(
    c(2L, 2L, 1L, 1L, 2L, 2L, 2L),
    list(c(1L, 2L, 1L, 2L, 1L, 3L, 4L, 5L, NA, 6L, NA, 6L))
  )
  expect_identical(ids, c(1L, 1L, 2L, 3L, 4L, 5L, 5L))

  expect_identical(cpp_sequence_pattern_id(integer(0), list(integer(0))), integer(0))

  expect_error(cpp_sequence_pattern_id(1L, list()))
  expect_error(cpp_sequence_pattern_id(c(1L, -1L), list(1L)))
  expect_error(cpp_sequence_pattern_id(c(1L, NA), list(1L)))
  expect_error(cpp_sequence_pattern_id(2L, list(c(1, 2))))
  expect_error(cpp_sequence_pattern_id(2L, list(1L)))
})

test_that("cpp_sequence_pattern_id compares every column, as feed_to_gps() uses it", {
  # feed_to_gps() passes two columns, the codes of stop_sequence and of stop_id.
  # Groups 1 and 2 share the first column but not the second; groups 1 and 3 share
  # both; group 4 has the values of group 1 in the other order; group 5 is empty,
  # as is group 6
  seq_codes <- c(1L, 2L, 1L, 2L, 1L, 2L, 2L, 1L)
  stop_codes <- c(7L, 8L, 7L, 9L, 7L, 8L, 8L, 7L)
  ids <- cpp_sequence_pattern_id(c(2L, 2L, 2L, 2L, 0L, 0L), list(seq_codes, stop_codes))
  expect_identical(ids, c(1L, 2L, 1L, 3L, 4L, 4L))

  # a column of a different length errors, whichever column it is
  expect_error(cpp_sequence_pattern_id(2L, list(c(1L, 2L), 1L)))
})

test_that("cpp_sequence_pattern_id matches a reference on random groups", {
  # the reference compares each group's values as an R list, which no separator
  # or hash collision can fool; ids are numbered in order of first appearance
  reference <- function(sizes, columns) {
    group <- rep(seq_along(sizes), sizes)
    keys <- lapply(seq_along(sizes), function(i) {
      lapply(columns, function(col) col[group == i])
    })
    return(match(keys, unique(keys)))
  }

  # the random number state is restored afterwards (withr is not a dependency)
  old_seed <- if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv())
  on.exit(if (is.null(old_seed)) rm(".Random.seed", envir = globalenv())
          else assign(".Random.seed", old_seed, envir = globalenv()), add = TRUE)
  set.seed(20261105)
  for (k in 1:20) {
    sizes <- sample(0:4, 60, replace = TRUE)
    n <- sum(sizes)
    # few distinct values, so that many groups repeat; some NAs
    columns <- list(sample(c(1:3, NA), n, replace = TRUE), sample(1:2, n, replace = TRUE))
    expect_identical(cpp_sequence_pattern_id(sizes, columns), reference(sizes, columns))
  }
})
