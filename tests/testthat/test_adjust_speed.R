test_that("adjust_speed", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package="gtfs2gps")) |>
        gtfstools::filter_by_weekday(c("monday", "tuesday", "wednesday", "thursday", "friday")) |>
        filter_single_trip()

    poa_gps <- gtfs2gps(poa)

    poa_gps_old <- data.table::copy(poa_gps)
    
    expect_true(any(is.na(poa_gps$speed)))
    expect_true(any(is.na(poa_gps$cumtime)))
    
    expect_equal(mean(units::drop_units(poa_gps$speed), na.rm = TRUE), 25.3999, 0.0001)
    expect_equal(mean(units::drop_units(poa_gps$cumtime), na.rm = TRUE), 1504.635, 0.001)

    poa_gps_new <- adjust_speed(poa_gps)

    expect_true(!any(is.na(poa_gps_new$speed)))
    expect_true(!any(is.na(poa_gps_new$cumtime)))
    
    expect_equal(mean(units::drop_units(poa_gps_new$speed)), 25.43416, 0.0001)
    expect_equal(mean(units::drop_units(poa_gps_new$cumtime)), 1514.028, 0.001)

    poa_gps_new <- adjust_speed(poa_gps, min_speed = 25, max_speed = 50)

    expect_false(all(poa_gps_new$speed >= units::set_units(25, "km/h"), na.rm = TRUE))
    expect_true(all(poa_gps_new$speed <= units::set_units(50, "km/h"), na.rm = TRUE))

    expect_equal(mean(units::drop_units(poa_gps_new$speed), na.rm = TRUE), 29.53442, 0.0001)
    expect_equal(mean(units::drop_units(poa_gps_new$cumtime)), 1317.878, 0.001)
})

test_that("adjust_speed keeps stop timestamps and dwell times", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
        gtfstools::filter_by_shape_id("T2-1") |>
        filter_single_trip() |>
        adjust_arrival_departure()  # 20 s dwell at the timed stops

    sp <- read_gtfs(system.file("extdata/saopaulo.zip", package = "gtfs2gps"), quiet = TRUE)
    sp <- gtfstools::filter_by_shape_id(sp, sp$shapes$shape_id[1])

    for(gtfs in list(poa, sp)){
        gps <- gtfs2gps(gtfs, parallel = FALSE, quiet = TRUE)
        adj <- adjust_speed(gps, min_speed = 0, max_speed = 1e6)

        timed_stops <- !is.na(gps$stop_id) & !is.na(gps$timestamp)
        expect_true(any(timed_stops))
        expect_equal(adj$timestamp[timed_stops], gps$timestamp[timed_stops])
    }
})

test_that("adjust_speed with clone = FALSE returns the updated input and adds no column", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
        gtfstools::filter_by_shape_id("T2-1") |>
        filter_single_trip()

    gps <- gtfs2gps(poa, parallel = FALSE, quiet = TRUE)
    cols <- names(gps)

    res <- adjust_speed(gps, clone = FALSE)

    expect_identical(res, gps)
    expect_identical(names(res), cols)
})

test_that("adjust_speed errors when no speed is within range", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
        gtfstools::filter_by_shape_id("T2-1") |>
        filter_single_trip()

    # 7 minutes for the whole trip: every speed is above 80 km/h
    poa$stop_times[stop_sequence == min(stop_sequence),
                   `:=`(arrival_time = "23:58:00", departure_time = "23:58:00")]
    poa$stop_times[stop_sequence == max(stop_sequence),
                   `:=`(arrival_time = "24:05:00", departure_time = "24:05:00")]

    gps <- gtfs2gps(poa, parallel = FALSE, quiet = TRUE)
    before <- data.table::copy(gps)

    expect_error(adjust_speed(gps), class = "gtfs2gps_no_valid_speed_error")
    # the input is untouched also when it is not cloned
    expect_error(adjust_speed(gps, clone = FALSE), class = "gtfs2gps_no_valid_speed_error")
    expect_identical(gps, before)

    expect_error(adjust_speed(gps, new_speed = 0), class = "gtfs2gps_invalid_speed_error")
    expect_error(adjust_speed(gps, new_speed = NA_real_), class = "gtfs2gps_invalid_speed_error")
})
