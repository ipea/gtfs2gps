test_that("adjust_arrival_departure", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package="gtfs2gps"))

    poa$stop_times[trip_id == "T2-1@1#520" & stop_id == 3608,
                   arrival_time := data.table::as.ITime("05:21:00", format = "%H:%M:%OS")]
    poa$stop_times[trip_id == "T2-1@1#520" & stop_id == 3564,
                   departure_time := data.table::as.ITime("05:22:00", format = "%H:%M:%OS")]

    before <- data.table::copy(poa)
    poa_adj <- adjust_arrival_departure(poa)

    # input data is not modified
    expect_identical(poa, before)

    poa_adj <- gtfstools::convert_time_to_seconds(poa_adj, file = "stop_times")
    st <- poa_adj$stop_times[!is.na(departure_time_secs)]

    expect_true(all(st$departure_time_secs >= st$arrival_time_secs + 20))
})

test_that("adjust_arrival_departure works when a time column is absent", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package="gtfs2gps"))

    # no arrival_time: created as departure_time - min_lag
    poa_no_arr <- data.table::copy(poa)
    poa_no_arr$stop_times[, arrival_time := NULL]
    before <- data.table::copy(poa_no_arr)

    poa_adj <- adjust_arrival_departure(poa_no_arr)

    expect_identical(poa_no_arr, before)
    expect_true("arrival_time" %in% names(poa_adj$stop_times))

    poa_adj <- gtfstools::convert_time_to_seconds(poa_adj, file = "stop_times")
    st <- poa_adj$stop_times[!is.na(departure_time_secs)]
    expect_true(nrow(st) > 0)
    expect_true(all(st$departure_time_secs - st$arrival_time_secs == 20))

    # no departure_time: created as arrival_time + min_lag
    poa_no_dep <- data.table::copy(poa)
    poa_no_dep$stop_times[, arrival_time := departure_time]
    poa_no_dep$stop_times[, departure_time := NULL]
    before <- data.table::copy(poa_no_dep)

    poa_adj <- adjust_arrival_departure(poa_no_dep)

    expect_identical(poa_no_dep, before)
    expect_true("departure_time" %in% names(poa_adj$stop_times))

    poa_adj <- gtfstools::convert_time_to_seconds(poa_adj, file = "stop_times")
    st <- poa_adj$stop_times[!is.na(arrival_time_secs)]
    expect_true(nrow(st) > 0)
    expect_true(all(st$departure_time_secs - st$arrival_time_secs == 20))
})

test_that("adjust_arrival_departure treats malformed times as missing", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package="gtfs2gps"))

    poa$stop_times[1, `:=`(arrival_time = "abc", departure_time = "05:21")]

    expect_warning(poa_adj <- adjust_arrival_departure(poa), class = "gtfstools_malformed_time")

    expect_equal(poa_adj$stop_times$arrival_time[1], "")
    expect_equal(poa_adj$stop_times$departure_time[1], "")

    expect_error(adjust_arrival_departure(poa, min_lag = -1))
})

test_that("adjust_arrival_departure keeps times non-negative and whole seconds", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package="gtfs2gps"))

    poa$stop_times[1:4, `:=`(arrival_time = c("00:00:05", NA, NA, "05:20:00"),
                             departure_time = c("00:00:05", "00:00:10", "00:00:00", "05:20:05"))]

    expect_warning(poa_adj <- adjust_arrival_departure(poa), NA)

    expect_equal(poa_adj$stop_times$arrival_time[1:4],
                 c("00:00:00", "00:00:00", "00:00:00", "05:19:53"))
    expect_equal(poa_adj$stop_times$departure_time[1:4],
                 c("00:00:20", "00:00:20", "00:00:20", "05:20:13"))

    # min_lag is rounded to whole seconds
    expect_identical(adjust_arrival_departure(poa, min_lag = 20.4), poa_adj)
})

test_that("adjust_arrival_departure accepts a plain list and returns a dt_gtfs", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package="gtfs2gps"))

    poa_list <- unclass(poa)
    before <- data.table::copy(poa_list)

    poa_adj <- adjust_arrival_departure(poa_list)

    expect_s3_class(poa_adj, "dt_gtfs")
    expect_identical(poa_list, before)
})
