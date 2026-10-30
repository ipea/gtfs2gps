test_that("cpp_expand_pattern gives the same result as the R reference", {
  # a shape template of 30 points with 9 stops; the stops in rows 10 and 11 are at
  # the same place (dist 0) and the stops in rows 5 and 6 are consecutive points
  n <- 30L
  stop_rows <- c(1L, 5L, 6L, 10L, 11L, 15L, 20L, 25L, 30L)
  dist <- c(0, rep(12.5, n - 1))
  dist[11] <- 0
  tpl <- list(stop_sequence = replace(rep(NA_integer_, n), stop_rows, 1:9)
              , has_stop = seq_len(n) %in% stop_rows
              , dist = dist
              , cumdist = cumsum(dist))

  dep0 <- 3600L + c(0L, 60L, 90L, 200L, 260L, 400L, 520L, 640L, 760L)
  trip <- function(seq, dep, arr = dep - 10L) list(seq = seq, dep = dep, arr = arr)
  trips <- list(
    normal = trip(1:9, dep0)
    # a duplicated stop_sequence: the last row wins
    , duplicated = trip(c(1:2, 2L, 3:9), c(dep0[1:2], dep0[2] + 20L, dep0[3:9]))
    # an NA stop_sequence matches every template row without a stop
    , na_sequence = trip(c(1:9, NA), c(dep0, 5000L))
    # but NaN does not match NA, as in match()
    , nan_sequence = trip(c(1:9, NaN), c(dep0, 5000L))
    # two stops at the same time but apart: Inf speed
    , same_time = trip(1:9, replace(dep0, 4, dep0[3]), replace(dep0, 4, dep0[3]))
    # two stops at the same time and place, followed by more segments: NaN
    , zero_zero = trip(1:9, replace(dep0, 5, dep0[4]), replace(dep0, 5, dep0[4]))
    # past 24:00 and across midnight
    , midnight = trip(1:9, 86000L + dep0 - dep0[1])
    # one of the two timed stops is not on the shape: must not fail
    , one_on_shape = trip(c(1L, 99L), c(3600L, 3700L))
    # fewer than two departures, or no stop_times at all: skipped
    , skipped = trip(1:9, c(dep0[1], rep(NA_integer_, 8)))
    , no_rows = trip(integer(0), integer(0))
    # a negative time (malformed) wraps as as.ITime() does
    , negative = trip(1:9, dep0 - 4000L)
    # stops without times are interpolated
    , untimed = trip(1:9, replace(dep0, c(2, 3, 7), NA_integer_), replace(dep0 - 10L, c(2, 3, 7), NA_integer_))
    # a stop with an arrival but no departure time is not timed
    , arrival_only = trip(1:9, replace(dep0, 4, NA_integer_))
  )
  # the template holds the times of the pattern's first trip
  tpl$departure_time <- replace(rep(NA_integer_, n), stop_rows, trips[[1]]$dep)
  tpl$arrival_time <- replace(rep(NA_integer_, n), stop_rows, trips[[1]]$arr)

  # trips[[k]] reads template number which[k] of the templates in tpls
  expand <- function(trips, tpls = list(tpl), which = rep(1L, length(trips))
                     , long_double = capabilities("long.double"), n_threads = 1L){
    col <- function(name) unlist(lapply(tpls, `[[`, name), use.names = FALSE)
    sizes <- lengths(lapply(tpls, `[[`, "dist"))
    cpp_expand_pattern(as.double(col("stop_sequence")), as.integer(col("departure_time"))
                       , as.integer(col("arrival_time")), col("has_stop"), col("dist"), col("cumdist")
                       , as.integer(cumsum(c(0L, sizes))[which]), as.integer(sizes[which])
                       , lengths(lapply(trips, `[[`, "seq"), use.names = FALSE)
                       , as.double(unlist(lapply(trips, `[[`, "seq"), use.names = FALSE))
                       , as.integer(unlist(lapply(trips, `[[`, "dep"), use.names = FALSE))
                       , as.integer(unlist(lapply(trips, `[[`, "arr"), use.names = FALSE))
                       , long_double, n_threads)
  }
  res <- expand(trips)
  ref <- suppressMessages(lapply(names(trips), function(k)
    update_dt(k, trips[[k]]$seq, trips[[k]]$dep, trips[[k]]$arr, tpl)))
  done <- !vapply(ref, is.null, logical(1))

  expect_identical(res$status, ifelse(done, 0L, 1L))
  expect_identical(res$n_rows, ifelse(done, vapply(ref, function(x) length(x$src), integer(1)), 0L))
  # the rows counted in the first pass are the rows written in the second
  expect_identical(sum(res$n_rows), length(res$src))
  for(col in c("src", "dist", "speed", "timestamp", "cumtime")){
    expect_identical(res[[col]], unlist(lapply(ref[done], `[[`, col), use.names = FALSE), info = col)
  }
  # the edge cases are reached
  expect_true(any(is.infinite(res$speed)))
  expect_true(any(is.nan(res$speed)))
  # the midnight trip has times on both sides of 00:00
  by_trip <- split(res$timestamp, rep(names(trips)[done], res$n_rows[done]))
  expect_true(any(by_trip$midnight >= 86000L, na.rm = TRUE))
  expect_true(any(by_trip$midnight < 1000L, na.rm = TRUE))

  # two threads (when compiled with OpenMP) give the same result
  expect_identical(expand(trips, n_threads = 2L), res)

  # summing in double (R built without long double) differs at most in the last bits
  res_d <- expand(trips, long_double = FALSE)
  expect_identical(res_d$src, res$src)
  expect_equal(res_d$cumtime, res$cumtime, tolerance = 1e-12)

  # trips read their own template: the same trips on a second template that is a copy
  # of the first give the same rows, with src offset by the first template
  two <- expand(trips[c("normal", "untimed")], tpls = list(tpl, tpl), which = c(2L, 1L))
  one <- expand(trips[c("normal", "untimed")])
  expect_identical(two$src, one$src + rep(c(n, 0L), one$n_rows))
  expect_identical(two$cumtime, one$cumtime)

  # a trip with no timed stop on the shape (and a template without times) fails, as
  # the R code did; the other trips are still computed, and the caller decides
  tpl$departure_time[] <- NA_integer_
  tpl$arrival_time[] <- NA_integer_
  failing <- list(none_on_shape = trip(c(98L, 99L), c(3600L, 3700L)), normal = trips$normal)
  expect_error(update_dt("none_on_shape", c(98L, 99L), c(3600L, 3700L), c(3590L, 3690L), tpl))
  expect_identical(expand(failing)$status, c(2L, 0L))
})
