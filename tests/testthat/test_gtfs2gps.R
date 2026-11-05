test_that("gtfs2gps", {
    poa <- system.file("extdata/poa.zip", package="gtfs2gps")

    poa_gps_0 <- read_gtfs(poa) |>
      adjust_arrival_departure() |>
      gtfstools::filter_by_weekday(c("monday", "tuesday", "wednesday", "thursday", "friday")) |>
      gtfs2gps(ncores = 1, spatial_resolution = 50)

    expect_equal(sum(units::drop_units(poa_gps_0$cumtime), na.rm = TRUE), 212843109, 0.01)
    expect_equal(sum(units::drop_units(poa_gps_0$speed), na.rm = TRUE), 3079200, 0.01)
    # cumdist restarts at 0 at each trip's first timed stop (#260)
    expect_equal(sum(units::drop_units(poa_gps_0$cumdist), na.rm = TRUE), 1412341424.583, 0.01)

    # only the points from the first to the last timed stop of each trip (#260), so
    # none has an NA speed and the filter below keeps every row
    my_dim_0 <- dim(poa_gps_0)[1]
    expect_equal(my_dim_0, 126737)
    expect_false(anyNA(poa_gps_0$speed))
    
    poa_gps <- poa_gps_0[units::drop_units(speed) > 0 & units::drop_units(cumtime) >= 0 & !is.na(speed),]
    
    my_dim <- dim(poa_gps)[1]
    expect_equal(my_dim, 126737)
    
    my_length <- length(poa_gps$dist[which(!units::drop_units(poa_gps$dist) < 50)])
    expect_equal(my_length, 0)
    
    expect_equal(sum(units::drop_units(poa_gps$dist)), 4069599.583, tolerance = 1e-6)

    # rounded to 3 decimals, except speeds that would round to 0 (1e-12 at stops)
    for(col in c("speed", "dist", "cumdist", "cumtime")){
      v <- units::drop_units(poa_gps_0[[col]])
      v <- v[!is.na(v) & !(round(v * 1000) == 0 & v != 0)]
      expect_identical(v, round(v * 1000) / 1000, info = col)
    }

    expect_true(poa_gps$trip_number[1] == 1)
    expect_true(poa_gps$trip_number[126737] == 88)
    
    expect_true(all(names(poa_gps) %in% 
                      c("trip_id", "route_type", "id", "shape_pt_lon", "shape_pt_lat", "trip_number",
                        "timestamp", "stop_id", "stop_sequence", "dist", "shape_id", "cumdist", "speed", "cumtime")))
    
    expect_true(all(!is.na(poa_gps$dist)))
    
    expect_true(all(poa_gps$dist >= units::set_units(0, "m")))
    expect_true(all(poa_gps$cumdist >= units::set_units(0, "m")))
    expect_true(all(poa_gps$speed >= units::set_units(0, "km/h")))
    expect_true(all(poa_gps$cumtime >= units::set_units(0, "s")))
    
    poa_gps <- read_gtfs(poa) |>
      gtfstools::filter_by_weekday(c("monday", "tuesday", "wednesday", "thursday", "friday")) |>
      gtfs2gps(spatial_resolution = 50)

    my_dim <- dim(poa_gps)[1]
    total <- 126737

    expect_equal(my_dim, total)

    poa_gps <- poa_gps[units::drop_units(speed) > 0 & units::drop_units(cumtime) > 0 & !is.na(speed) & !is.infinite(speed),]

    expect_true(all(na.omit(units::drop_units(poa_gps$speed) > 0)))
    
    my_dim <- dim(poa_gps)[1]
    expect_equal(my_dim, 126349)
    
    my_length <- length(poa_gps$dist[which(!(units::drop_units(poa_gps$dist) < 50))])
    expect_equal(my_length, 0)
    
    expect_equal(sum(units::drop_units(poa_gps$dist)), 4069599.583, tolerance = 1e-6)

    expect_true(poa_gps$trip_number[1] == 1)
    expect_true(poa_gps$trip_number[126349] == 88)
    
    expect_true(all(names(poa_gps) %in% 
      c("trip_id", "route_type", "id", "shape_pt_lon", "shape_pt_lat", "trip_number",
        "timestamp", "stop_id", "stop_sequence", "dist", "shape_id", "cumdist", "speed", "cumtime")))
    
    expect_true(all(!is.na(poa_gps$dist)))
    
    expect_true(all(poa_gps$dist >= units::set_units(0, "m")))
    expect_true(all(poa_gps$cumdist >= units::set_units(0, "m")))
    expect_true(all(poa_gps$speed >= units::set_units(0, "km/h")))
    expect_true(all(poa_gps$cumtime >= units::set_units(0, "s")))

    poa_gps_30 <- read_gtfs(poa) |>
      gtfstools::filter_by_weekday(c("monday", "tuesday", "wednesday", "thursday", "friday")) |>
      gtfs2gps(spatial_resolution = 30)
    
    expect_equal(dim(poa_gps_30)[1], 197455)
    expect_true(dim(poa_gps_30)[1] > dim(poa_gps)[1])
    
    # save into files, in a temporary directory
    out_dir <- tempfile("g2g_")
    dir.create(out_dir)
    on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

    poa_simple <- read_gtfs(poa) |>
      gtfstools::filter_by_shape_id(c("T2-1", "A141-1"))

    poa_gps <- gtfs2gps(poa_simple, filepath = out_dir, spatial_resolution = 50)
    expect_null(poa_gps)

    poa_gps <- gtfs2gps(poa, filepath = out_dir, continue = TRUE, spatial_resolution = 50)

    expect_null(poa_gps)

    files1 <- list.files(out_dir, pattern = "\\.txt$", full.names = TRUE)
    names <- gsub('.{4}$', '', files1)
    
    # poa_shape <- gtfs_shapes_as_sf(read_gtfs(poa))
    # expect_setequal(poa_shape$shape_id[2:3], names[c(1,4)])

    poa_gps <- gtfs2gps(poa, filepath = out_dir, compress = TRUE, spatial_resolution = 50)

    expect_null(poa_gps)

    files2 <- list.files(out_dir, pattern = "\\.rds$", full.names = TRUE)
    names2 <- gsub('.{4}$', '', files2)
    
    data1 <- data.table::fread(files1[1])

    # note how the types are converted    
    data1[, timestamp := data.table::as.ITime(timestamp)]
    data1[, stop_id := as.character(stop_id)]
    data1[, trip_number := as.double(trip_number)]
    
    data2 <- readRDS(files2[1])
    
    expect_true(all(data1$trip_id == data2$trip_id))
    
    # poa_shape <- gtfs_shapes_as_sf(read_gtfs(poa))
    # expect_setequal(poa_shape$shape_id[2:3], names[c(1,4)])
    
    sp <- system.file("extdata/saopaulo.zip", package="gtfs2gps")

    expect_error(gtfs2gps(sp, continue = TRUE), class = "gtfs2gps_filepath_error")
    expect_error(gtfs2gps(sp, compress = TRUE), class = "gtfs2gps_filepath_error")

    # compress, continue and quiet must be a single TRUE or FALSE (checked before
    # the feed is read)
    expect_error(gtfs2gps(sp, compress = "yes"), "compress")
    expect_error(gtfs2gps(sp, compress = 1), "compress")
    expect_error(gtfs2gps(sp, continue = NA), "continue")
    expect_error(gtfs2gps(sp, quiet = NA), "quiet")
    expect_error(gtfs2gps(sp, quiet = c(TRUE, FALSE)), "quiet")

    # strategy is deprecated (compress without filepath then stops before any work).
    # testthat edition 2 ignores the class in expect_warning(), so it is checked here
    expect_s3_class(tryCatch(gtfs2gps(sp, strategy = "sequential", compress = TRUE),
                             warning = identity), "deprecated_strategy")
    expect_error(suppressWarnings(gtfs2gps(sp, strategy = "sequential", compress = TRUE)),
                 class = "gtfs2gps_filepath_error")

    # parallel is deprecated; the warning is not hidden by quiet
    expect_s3_class(tryCatch(gtfs2gps(sp, parallel = FALSE, compress = TRUE, quiet = TRUE),
                             warning = identity), "deprecated_parallel")
    expect_error(suppressWarnings(gtfs2gps(sp, parallel = FALSE, compress = TRUE, quiet = TRUE)),
                 class = "gtfs2gps_filepath_error")

    # ncores must be a positive count or Inf (checked before the feed is read)
    expect_error(gtfs2gps(sp, ncores = 0), "ncores")
    expect_error(gtfs2gps(sp, ncores = -Inf), "ncores")

})

test_that("gtfs2gps converts every trip of a shared shape with its own stop pattern", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package="gtfs2gps"), quiet = TRUE)
    poa <- gtfstools::filter_by_trip_id(poa, c("A141-1@1#30", "A141-1@1#520"))

    # second trip: another route (different route_type) on the same shape ...
    poa$routes <- rbind(poa$routes, poa$routes)
    poa$routes[2, `:=`(route_id = "other_route", route_type = 0L)]
    poa$trips[trip_id == "A141-1@1#520", route_id := "other_route"]

    # ... and a different stop pattern: it skips stop_sequence 2
    poa$stop_times <- poa$stop_times[!(trip_id == "A141-1@1#520" & stop_sequence == 2)]

    poa_old <- data.table::copy(poa)
    result <- gtfs2gps(poa, ncores = 1, quiet = TRUE)
    expect_equal(poa, poa_old)

    # both trips are converted, each with the route_type of its own route
    expect_setequal(unique(result$trip_id), c("A141-1@1#30", "A141-1@1#520"))
    route_types <- unique(result[, c("trip_id", "route_type")])
    expect_equal(route_types[trip_id == "A141-1@1#30"]$route_type, poa$routes$route_type[1])
    expect_equal(route_types[trip_id == "A141-1@1#520"]$route_type, 0L)
    expect_equal(sort(unique(result$trip_number)), 1:2)

    # each trip only has the stops it serves
    out_stops <- unique(result[!is.na(stop_id), c("trip_id", "stop_id", "stop_sequence")])
    in_stops <- unique(poa$stop_times[, c("trip_id", "stop_id", "stop_sequence")])
    expect_equal(nrow(data.table::fsetdiff(out_stops, in_stops)), 0)  # no made-up stops
    expect_equal(nrow(data.table::fsetdiff(in_stops, out_stops)), 0)  # no lost stops
    expect_false(any(result$trip_id == "A141-1@1#520" & result$stop_sequence %in% 2))
})

test_that("gtfs2gps wraps timestamps at midnight and matches in parallel", {
    # the first and last stops of this trip, its only timed ones, across midnight
    poa <- test_gtfs_midnight()

    before <- data.table::copy(poa)
    seq_res <- gtfs2gps(poa, ncores = 1, spatial_resolution = 50, quiet = TRUE)
    expect_equal(poa, before)  # input not modified

    # every timestamp is within the day; elapsed time keeps growing in cumtime
    expect_lt(max(as.integer(seq_res$timestamp), na.rm = TRUE), 86400)
    expect_true(any(as.integer(seq_res$timestamp) < 3600, na.rm = TRUE))
    expect_false(is.unsorted(units::drop_units(seq_res$cumtime), na.rm = TRUE))

    # every row has a speed, also across midnight
    expect_false(anyNA(seq_res$speed))

    # two threads give the same result; quiet hides the messages and progress steps
    expect_no_message(par_res <- gtfs2gps(poa, ncores = 2, spatial_resolution = 50, quiet = TRUE))
    expect_identical(as.list(seq_res), as.list(par_res))

    # ncores = Inf uses all of data.table's threads (here at most 2)
    old_threads <- data.table::setDTthreads(2)
    on.exit(data.table::setDTthreads(old_threads), add = TRUE)
    inf_res <- gtfs2gps(poa, ncores = Inf, spatial_resolution = 50, quiet = TRUE)
    expect_identical(as.list(seq_res), as.list(inf_res))
})

test_that("gtfs2gps shows a progress bar over the shapes with filepath", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
      gtfstools::filter_by_shape_id(c("T2-1", "A141-1")) |>
      filter_single_trip()

    # the default handler draws nothing in tests; the logger prints every event
    op <- options(cli.progress_handlers_only = "logger")
    out_dir <- tempfile("g2g_"); dir.create(out_dir)
    on.exit({options(op); unlink(out_dir, recursive = TRUE)}, add = TRUE)
    out <- capture.output(suppressMessages(gtfs2gps(poa, ncores = 1, filepath = out_dir)))

    # steps have no total (logged as /NA), so these lines are the bar's
    expect_true(any(grepl("0/2 created", out, fixed = TRUE)))
    expect_true(any(grepl("2/2 terminated", out, fixed = TRUE)))
    expect_length(list.files(out_dir), 2)
})

test_that("gtfs2gps raises an error when no shape converts", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
      gtfstools::filter_by_shape_id("T2-1") |>
      filter_single_trip()

    # only the first stop keeps its times, so the trip can't be timed
    poa$stop_times[stop_sequence == max(stop_sequence),
                   `:=`(arrival_time = "", departure_time = "")]

    e <- tryCatch(gtfs2gps(poa, ncores = 1, quiet = TRUE), error = identity)
    expect_s3_class(e, "gtfs2gps_nothing_converted_error")

    out_dir <- tempfile("g2g_"); dir.create(out_dir); on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)
    e <- tryCatch(gtfs2gps(poa, ncores = 1, filepath = out_dir, quiet = TRUE), error = identity)
    expect_s3_class(e, "gtfs2gps_nothing_converted_error")
    expect_length(list.files(out_dir), 0)

    # with continue, a shape already saved counts as converted
    file.create(file.path(out_dir, "T2-1.txt"))
    expect_null(gtfs2gps(poa, ncores = 1, filepath = out_dir, continue = TRUE, quiet = TRUE))
})

test_that("gtfs2gps takes the route_type of the shape a trip is converted with", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
      gtfstools::filter_by_shape_id(c("T2-1", "A141-1")) |>
      filter_single_trip()
    poa$routes[route_id == "A141", route_type := 0L]
    # the T2-1 trip is also listed, later, under A141-1 (invalid GTFS): its stop_times
    # stay with T2-1, the first shape listing it, and so does its route
    trip <- poa$trips[shape_id == "T2-1"]
    poa$trips <- rbind(poa$trips, trip[, `:=`(shape_id = "A141-1", route_id = "A141")])

    old <- data.table::copy(poa)
    res <- gtfs2gps(poa, ncores = 1, quiet = TRUE)
    expect_equal(poa, old)  # input not modified

    expect_identical(unique(res[trip_id == trip$trip_id, .(shape_id, route_type)])
                     , data.table::data.table(shape_id = "T2-1", route_type = 3L))
    expect_identical(unique(res[shape_id == "A141-1"]$route_type), 0L)

    # the units and timestamp class are set once for the whole output
    expect_identical(lapply(res[, .(speed, dist, cumdist, cumtime)], units::deparse_unit)
                     , list(speed = "km h-1", dist = "m", cumdist = "m", cumtime = "s"))
    expect_s3_class(res$timestamp, "ITime")

    # without a valid routes table, gtfs2gps() stops before any work
    no_route_id <- data.table::copy(poa)
    no_route_id$routes[, route_id := NULL]
    e <- tryCatch(gtfs2gps(no_route_id, ncores = 1, quiet = TRUE), error = identity)
    expect_s3_class(e, "gtfs2gps_missing_routes_error")
    expect_match(conditionMessage(e), "route_id")

    no_routes <- data.table::copy(poa)
    no_routes$routes <- NULL
    before <- data.table::copy(no_routes)
    expect_silent(e <- tryCatch(gtfs2gps(no_routes, ncores = 1, quiet = TRUE), error = identity))
    expect_s3_class(e, "gtfs2gps_missing_routes_error")
    expect_match(conditionMessage(e), "routes.txt")
    expect_identical(no_routes, before)
})

test_that("gtfs2gps ignores trips with an NA trip_id", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
      gtfstools::filter_by_shape_id(c("T2-1", "A141-1")) |>
      filter_single_trip()
    ref <- gtfs2gps(poa, ncores = 1, quiet = TRUE)

    # a copy of the T2-1 trip with an NA trip_id and one stop less, so that it would have
    # a pattern of its own: it is dropped before gtfstools::remove_unused_ids(), which
    # errors on NA ids, and the rest of the shape is still converted
    trip <- poa$trips[shape_id == "T2-1"]
    tripid <- trip$trip_id
    st <- poa$stop_times[trip_id == tripid][-1]
    poa$trips <- rbind(poa$trips, trip[, trip_id := NA_character_])
    poa$stop_times <- rbind(poa$stop_times, st[, trip_id := NA_character_])

    res <- gtfs2gps(poa, ncores = 1, quiet = TRUE)
    expect_true(tripid %in% res$trip_id)
    expect_identical(res, ref)
})

test_that("gtfs2gps gives the same result when the shapes are segmentized one by one", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
      gtfstools::filter_by_shape_id(c("T2-1", "A141-1")) |>
      filter_single_trip()
    ref <- gtfs2gps(poa, ncores = 1, quiet = TRUE)

    # segmentizing all shapes at once fails: each shape is segmentized on its own
    segmentize <- sf::st_segmentize
    calls <- 0
    # sf's own methods call the generic again on the geometry column (sfc)
    local_mocked_bindings(st_segmentize = function(x, ...){
      if(inherits(x, "sf")){
        calls <<- calls + 1
        if(nrow(x) > 1) stop("all shapes at once")
      }
      segmentize(x, ...)
    }, .package = "sf")
    expect_identical(gtfs2gps(poa, ncores = 1, quiet = TRUE), ref)
    expect_equal(calls, 3)  # the failing call, then one per shape
})

test_that("gtfs2gps stops with a cli error when the output has too many points", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
      gtfstools::filter_by_shape_id(c("T2-1", "A141-1")) |>
      filter_single_trip()
    out_dir <- tempfile("g2g_"); dir.create(out_dir); on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

    # the C++ error, raised once the size is known; not reported as a failed shape
    calls <- 0
    local_mocked_bindings(cpp_expand_pattern = function(...){
      calls <<- calls + 1
      stop("Too many GPS points (more than 2147483647).")
    })
    e <- tryCatch(gtfs2gps(poa, ncores = 1, quiet = TRUE), error = identity)
    expect_s3_class(e, "gtfs2gps_too_many_points_error")
    expect_match(conditionMessage(e), "spatial_resolution")
    expect_equal(calls, 1)  # no shape-by-shape retry
    e <- tryCatch(gtfs2gps(poa, ncores = 1, quiet = TRUE, filepath = out_dir), error = identity)
    expect_s3_class(e, "gtfs2gps_too_many_points_error")
    expect_equal(calls, 2)
})

test_that("gtfs2gps raises an error for a feed without stops or stop coordinates", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
      gtfstools::filter_by_shape_id("T2-1") |>
      filter_single_trip()
    # filepath: with no output at all, the final speed checks would fail on an empty table
    out_dir <- tempfile("g2g_"); dir.create(out_dir); on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

    no_stop_times <- data.table::copy(poa)
    no_stop_times$stop_times <- no_stop_times$stop_times[0]
    # gtfstools::remove_unused_ids() drops the trip without stop_times and then its shape,
    # so nothing is left to convert: the error comes before any work is done
    e <- tryCatch(gtfs2gps(no_stop_times, ncores = 1, filepath = out_dir, quiet = TRUE),
                  error = identity)
    expect_s3_class(e, "gtfs2gps_nothing_converted_error")
    expect_match(conditionMessage(e), "nothing to convert")

    no_stops <- data.table::copy(poa)
    no_stops$stops <- no_stops$stops[0]
    expect_message(e <- tryCatch(gtfs2gps(no_stops, ncores = 1, filepath = out_dir),
                                 error = identity),
                   "no snapped stops")
    expect_s3_class(e, "gtfs2gps_nothing_converted_error")

    expect_length(list.files(out_dir, pattern = "^T2-1"), 0)
})

test_that("gtfs2gps reports a shape that errors, also when running in parallel", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
      gtfstools::filter_by_shape_id("T2-1") |>
      filter_single_trip()
    poa$stops[, stop_lon := NULL]  # makes the stop join fail
    out_dir <- tempfile("g2g_"); dir.create(out_dir); on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

    expect_warning(e <- tryCatch(gtfs2gps(poa, ncores = 2, filepath = out_dir),
                                 error = identity),
                   "internal bug")
    expect_s3_class(e, "gtfs2gps_nothing_converted_error")
    expect_length(list.files(out_dir, pattern = "^T2-1"), 0)

    # the report is a warning, so quiet = TRUE does not hide it
    expect_warning(tryCatch(gtfs2gps(poa, ncores = 1, filepath = out_dir, quiet = TRUE),
                            gtfs2gps_nothing_converted_error = function(e) NULL),
                   "internal bug")
})

test_that("gtfs2gps converts a shape whose id is the empty string", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
      gtfstools::filter_by_shape_id("T2-1") |>
      filter_single_trip()
    ref <- gtfs2gps(poa, ncores = 1, spatial_resolution = 50, quiet = TRUE)

    poa$trips[, shape_id := ""]
    poa$shapes[, shape_id := ""]
    res <- gtfs2gps(poa, ncores = 1, spatial_resolution = 50, quiet = TRUE)

    expect_equal(nrow(res), nrow(ref))
    expect_true(all(res$shape_id == ""))
})

test_that("gtfs2gps(continue = TRUE) skips shapes already saved, with and without compress", {
    shapes <- c("T2-1", "A141-1")
    poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
      gtfstools::filter_by_shape_id(shapes) |>
      filter_single_trip()

    for (compress in c(FALSE, TRUE)) {
      out_dir <- tempfile("g2g_"); dir.create(out_dir); on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)
      files <- file.path(out_dir, paste0(shapes, if (compress) ".rds" else ".txt"))

      gtfs2gps(poa, ncores = 1, filepath = out_dir, compress = compress, quiet = TRUE)
      expect_true(all(file.exists(files)))

      # a saved shape must be skipped (its file left as it is), a missing one written again
      writeLines("already saved", files[1])
      unlink(files[2])
      gtfs2gps(poa, ncores = 1, filepath = out_dir, compress = compress, continue = TRUE, quiet = TRUE)
      expect_identical(readLines(files[1]), "already saved")
      expect_true(file.exists(files[2]))
    }
})

test_that("gtfs2gps drops only the shape of a trip with fewer than two timed stops on it", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
      gtfstools::filter_by_shape_id(c("T2-1", "A141-1")) |>
      filter_single_trip()
    shapes <- shapes_as_sf(poa)
    points <- sf::st_segmentize(shapes[shapes$shape_id == "T2-1", ], units::set_units(0.1, "km")) |>
      sfheaders::sf_cast("POINT") |>
      sf::st_coordinates()

    # the last two stops of T2-1 at its last point: both are snapped there, as the
    # shape has no point left after it, and the last one takes it. Timed only at those
    # two stops, with no arrival time at the last one, the trip has a single timed
    # stop on the shape
    tripid <- poa$trips[shape_id == "T2-1"]$trip_id
    st <- poa$stop_times[trip_id == tripid][order(stop_sequence)]
    poa$stops[stop_id %in% utils::tail(st$stop_id, 2)
              , `:=`(stop_lon = points[nrow(points), 1], stop_lat = points[nrow(points), 2])]
    seqs <- utils::tail(st$stop_sequence, 2)
    poa$stop_times[trip_id == tripid, `:=`(arrival_time = "", departure_time = "")]
    poa$stop_times[trip_id == tripid & stop_sequence == seqs[1]
                   , `:=`(arrival_time = "08:00:00", departure_time = "08:00:00")]
    poa$stop_times[trip_id == tripid & stop_sequence == seqs[2], departure_time := "08:10:00"]
    # a second trip of the same pattern fails too, but only the first is reported
    poa$trips <- rbind(poa$trips, data.table::copy(poa$trips[trip_id == tripid])[, trip_id := "zzz"])
    poa$stop_times <- rbind(poa$stop_times
                            , data.table::copy(poa$stop_times[trip_id == tripid])[, trip_id := "zzz"])

    res <- suppressWarnings(gtfs2gps(poa, ncores = 1, quiet = TRUE))
    expect_identical(unique(res$shape_id), "A141-1")
    w <- tryCatch(gtfs2gps(poa, ncores = 1, quiet = TRUE), warning = function(w) w)
    expect_s3_class(w, "gtfs2gps_shape_error")
    expect_match(conditionMessage(w), tripid, fixed = TRUE)
    expect_false(grepl("zzz", conditionMessage(w), fixed = TRUE))
    # the code to reproduce it names the user's object, also with quiet = TRUE, and a
    # placeholder when the call names none
    expect_match(conditionMessage(w), "filter_by_shape_id(poa, ids)", fixed = TRUE)
    # the code lines are not wrapped, even on a narrow console
    old <- options(cli.width = 40); on.exit(options(old), add = TRUE)
    w <- tryCatch(gtfs2gps(poa, ncores = 1, quiet = TRUE), warning = function(w) w)
    expect_match(conditionMessage(w), "data <- gtfstools::filter_by_shape_id(poa, ids)", fixed = TRUE)
    options(old)
    w <- tryCatch(lapply(list(poa), gtfs2gps, ncores = 1, quiet = TRUE), warning = function(w) w)
    expect_match(conditionMessage(w), "<your gtfs data>", fixed = TRUE)
})

test_that("gtfs2gps converts several shapes as it converts each one", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
      gtfstools::filter_by_shape_id(c("T2-1", "A141-1")) |>
      filter_single_trip()
    both <- gtfs2gps(poa, ncores = 1, quiet = TRUE)
    each <- lapply(unique(both$shape_id), function(id)
      gtfs2gps(gtfstools::filter_by_shape_id(poa, id), ncores = 1, quiet = TRUE))

    # distances restart at each shape
    expect_identical(both, data.table::rbindlist(each))
})

test_that("gtfs2gps runs each trip from its first to its last timed stop (#260)", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
      gtfstools::filter_by_shape_id(c("T2-1", "A141-1")) |>
      filter_single_trip()

    # T2-1's shape starts before its first stop and ends after its last one: those
    # points have no time, and are not returned
    before <- data.table::copy(poa)
    expect_no_message(res <- gtfs2gps(poa, ncores = 1), message = "are NA")
    expect_equal(poa, before)  # input not modified
    for (col in c("speed", "timestamp", "cumtime")) {
      expect_false(anyNA(res[[col]]), info = col)
    }

    st <- poa$stop_times[order(trip_id, stop_sequence)]
    for (tripid in unique(res$trip_id)) {
      trip <- res[res$trip_id == tripid]
      stops <- st[st$trip_id == tripid]
      # the vehicle starts stopped at the first stop, ends at the last one
      expect_identical(trip$stop_id[1], stops$stop_id[1])
      expect_identical(trip$stop_id[nrow(trip)], stops$stop_id[nrow(stops)])
      expect_identical(units::drop_units(trip$speed[1]), 1e-12)
      for (col in c("dist", "cumdist", "cumtime")) {
        expect_identical(units::drop_units(trip[[col]][1]), 0, info = col)
      }
      # cumdist restarts at each trip (dist is rounded per row, so its sum drifts)
      expect_equal(units::drop_units(trip$cumdist),
                   cumsum(units::drop_units(trip$dist)), tolerance = 0.5, scale = 1)
    }

    # a frequency-based feed: every trip of the shape starts and ends at a timed stop
    sp <- read_gtfs(system.file("extdata/saopaulo.zip", package = "gtfs2gps"), quiet = TRUE)
    sp <- gtfstools::filter_by_shape_id(sp, sp$shapes$shape_id[1])
    sp_res <- gtfs2gps(sp, ncores = 1, quiet = TRUE)
    expect_false(anyNA(sp_res$speed))
    ends <- sp_res[, .(first_stop = !is.na(stop_id[1]), last_stop = !is.na(stop_id[.N]),
                       first_cumdist = units::drop_units(cumdist[1])), by = trip_number]
    expect_true(all(ends$first_stop & ends$last_stop))
    expect_true(all(ends$first_cumdist == 0))
})

test_that("gtfs2gps converts a trip listed under two shapes once, also shape by shape", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
      gtfstools::filter_by_shape_id(c("T2-1", "A141-1")) |>
      filter_single_trip()
    trip <- poa$trips[shape_id == "T2-1"]
    poa$trips <- rbind(poa$trips, data.table::copy(trip)[, `:=`(shape_id = "A141-1", route_id = "A141")])
    ref <- gtfs2gps(poa, ncores = 1, quiet = TRUE)
    # (no `trip_id ==` in i: it would add an index to ref)
    expect_identical(unique(ref$shape_id[ref$trip_id == trip$trip_id]), "T2-1")

    # with filepath, each shape is converted on its own
    out_dir <- tempfile("g2g_"); dir.create(out_dir); on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)
    gtfs2gps(poa, ncores = 1, filepath = out_dir, compress = TRUE, quiet = TRUE)
    files <- lapply(file.path(out_dir, paste0(unique(ref$shape_id), ".rds")), readRDS)
    expect_identical(data.table::rbindlist(files), ref)

    # and when segmentizing all shapes at once fails
    segmentize <- sf::st_segmentize
    local_mocked_bindings(st_segmentize = function(x, ...){
      if(inherits(x, "sf") && nrow(x) > 1) stop("all shapes at once")
      segmentize(x, ...)
    }, .package = "sf")
    expect_identical(gtfs2gps(poa, ncores = 1, quiet = TRUE), ref)
})

test_that("gtfs2gps(filepath) reports a shape whose file can't be written and writes the others", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
      gtfstools::filter_by_shape_id(c("T2-1", "A141-1")) |>
      filter_single_trip()
    out_dir <- tempfile("g2g_"); dir.create(out_dir); on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)
    # a folder where the file of A141-1 should go
    dir.create(file.path(out_dir, "A141-1.txt"))

    expect_warning(res <- gtfs2gps(poa, ncores = 1, filepath = out_dir, quiet = TRUE)
                   , "internal bug")
    expect_null(res)
    expect_true(file.exists(file.path(out_dir, "T2-1.txt")))
    expect_true(dir.exists(file.path(out_dir, "A141-1.txt")))
})

test_that("gtfs2gps(filepath) writes shapes whose id can't be a file name", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
      gtfstools::filter_by_shape_id(c("T2-1", "A141-1")) |>
      filter_single_trip()
    ref <- gtfs2gps(poa, ncores = 1, quiet = TRUE)
    # ids that would point into a folder, or that some systems reject, plus "%",
    # which is encoded so that names stay distinct
    ids <- c("T2-1" = "a/b:c", "A141-1" = "50%2F")
    for(old in names(ids)){
      poa$trips[shape_id == old, shape_id := ids[[old]]]
      poa$shapes[shape_id == old, shape_id := ids[[old]]]
    }
    out_dir <- tempfile("g2g_"); dir.create(out_dir); on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

    expect_null(gtfs2gps(poa, ncores = 1, filepath = out_dir, compress = TRUE, quiet = TRUE))
    files <- list.files(out_dir)
    expect_setequal(files, c("a%2Fb%3Ac.rds", "50%252F.rds"))
    expect_setequal(unname(vapply(sub("[.]rds$", "", files), utils::URLdecode, "")), unname(ids))

    # the files hold the same points
    a <- readRDS(file.path(out_dir, "a%2Fb%3Ac.rds"))
    expect_equal(nrow(a), nrow(ref[shape_id == "T2-1"]))
    expect_identical(unique(a$shape_id), "a/b:c")

    # continue finds the files under the same names
    expect_null(gtfs2gps(poa, ncores = 1, filepath = out_dir, compress = TRUE,
                         continue = TRUE, quiet = TRUE))
    expect_setequal(list.files(out_dir), files)
})

test_that("gtfs2gps drops an unused shape before segmentizing it", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
      gtfstools::filter_by_shape_id(c("T2-1", "A141-1")) |>
      filter_single_trip()
    ref <- gtfs2gps(poa, ncores = 1, quiet = TRUE)
    # an unused copy of T2-1, whose geometry makes segmentizing fail
    poa$shapes <- rbind(poa$shapes, data.table::copy(poa$shapes[shape_id == "T2-1"])[, shape_id := "U"])
    segmentize <- sf::st_segmentize
    local_mocked_bindings(st_segmentize = function(x, ...){
      if(inherits(x, "sf") && "U" %in% x$shape_id) stop("bad geometry")
      segmentize(x, ...)
    }, .package = "sf")

    # gtfstools::remove_unused_ids() drops it, so its geometry is never segmentized
    expect_no_warning(res <- gtfs2gps(poa, ncores = 1, quiet = TRUE))
    expect_identical(res, ref)
})

test_that("gtfs2gps takes the route of the last row of a trip listed twice in a shape", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
      gtfstools::filter_by_shape_id("T2-1") |>
      filter_single_trip()
    # the trip is listed again with a route that is not in routes: its route_type is NA
    poa$trips <- rbind(poa$trips, data.table::copy(poa$trips)[, route_id := "not a route"])
    res <- gtfs2gps(poa, ncores = 1, quiet = TRUE)
    expect_true(all(is.na(res$route_type)))
    expect_type(res$route_type, "integer")
    expect_s3_class(res$speed, "units")
    expect_type(unclass(res$speed), "double")
})

test_that("gtfs2gps() takes spatial_resolution in metres or as a units length", {
    poa <- system.file("extdata/poa.zip", package = "gtfs2gps")
    gtfs <- read_gtfs(poa) |>
      gtfstools::filter_by_shape_id("T2-1")
    gtfs$trips <- gtfs$trips[1]

    res_m <- gtfs2gps(gtfs, spatial_resolution = 50, ncores = 1, quiet = TRUE)
    res_km <- gtfs2gps(gtfs, spatial_resolution = units::set_units(0.05, "km"), ncores = 1, quiet = TRUE)
    expect_identical(res_km, res_m)

    expect_error(gtfs2gps(gtfs, spatial_resolution = 0.5, ncores = 1, quiet = TRUE), "spatial_resolution")
    expect_error(gtfs2gps(gtfs, spatial_resolution = units::set_units(1, "ft"), ncores = 1, quiet = TRUE), "spatial_resolution")
    expect_error(gtfs2gps(gtfs, spatial_resolution = units::set_units(50, "s"), ncores = 1, quiet = TRUE), "cannot convert")
})

test_that("gtfs2gps converts a trip with a stop far from its shape", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
      gtfstools::filter_by_shape_id("T2-1") |>
      filter_single_trip()
    # a stop in the middle of the trip about 2 km from the shape (nearest2 used to
    # drop the whole stop pattern)
    st <- poa$stop_times[order(stop_sequence)]
    far <- st$stop_id[nrow(st) %/% 2]
    poa$stops[stop_id == far, stop_lat := stop_lat + 0.018]

    res <- gtfs2gps(poa, ncores = 1, quiet = TRUE)
    expect_setequal(unique(res$stop_sequence[!is.na(res$stop_sequence)]), st$stop_sequence)
})

test_that("gtfs2gps warns that snap_method is deprecated and keeps the thread count", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
      gtfstools::filter_by_shape_id("T2-1") |>
      filter_single_trip()
    ref <- gtfs2gps(poa, ncores = 1, quiet = TRUE)

    threads <- data.table::getDTthreads()
    # (testthat edition 2 ignores the class in expect_warning(), so it is checked here)
    cls <- character(0)
    res <- withCallingHandlers(gtfs2gps(poa, ncores = 1, snap_method = "nearest1", quiet = TRUE),
                               warning = function(w){
                                 cls <<- c(cls, class(w))
                                 invokeRestart("muffleWarning")
                               })
    expect_true("deprecated_snap_method" %in% cls)
    expect_identical(res, ref)
    expect_identical(data.table::getDTthreads(), threads)
})

test_that("gtfs2gps skips patterns with a stop without coordinates or a single stop, and handles repeated shape points", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
      gtfstools::filter_by_shape_id(c("T2-1", "A141-1")) |>
      filter_single_trip()
    ref <- gtfs2gps(poa, ncores = 1, quiet = TRUE)
    t2 <- poa$trips[shape_id == "T2-1"]$trip_id
    a141 <- poa$trips[shape_id == "A141-1"]$trip_id
    st_t2 <- poa$stop_times[trip_id == t2][order(stop_sequence)]
    st_a141 <- poa$stop_times[trip_id == a141][order(stop_sequence)]

    # a stop in the middle of the T2-1 trip, used by no other trip, without coordinates
    no_coords <- setdiff(st_t2$stop_id, st_a141$stop_id)
    no_coords <- no_coords[length(no_coords) %/% 2]
    poa$stops[stop_id == no_coords, `:=`(stop_lat = NA_real_, stop_lon = NA_real_)]
    # a trip of A141-1 with a single stop
    poa$trips <- rbind(poa$trips, data.table::copy(poa$trips[trip_id == a141])[, trip_id := "single"])
    poa$stop_times <- rbind(poa$stop_times, data.table::copy(st_a141[1])[, trip_id := "single"])
    # a point of the A141-1 shape repeated
    shp <- poa$shapes[shape_id == "A141-1"][order(shape_pt_sequence)]
    shp[, shape_pt_sequence := 2L * seq_len(.N)]
    rep_pt <- data.table::copy(shp[.N %/% 2])[, shape_pt_sequence := shape_pt_sequence + 1L]
    poa$shapes <- rbind(poa$shapes[shape_id != "A141-1"], shp, rep_pt)

    msgs <- character(0)
    res <- withCallingHandlers(gtfs2gps(poa, ncores = 1),
                               message = function(m){
                                 msgs <<- c(msgs, conditionMessage(m))
                                 invokeRestart("muffleMessage")
                               })
    expect_true(any(grepl("T2-1.*no snapped stops", msgs)))
    expect_true(any(grepl("A141-1.*less than two stops", msgs)))
    expect_false(t2 %in% res$trip_id)
    expect_false("single" %in% res$trip_id)
    # each stop of the A141-1 trip once, as without the repeated point
    expect_identical(res[trip_id == a141 & !is.na(stop_sequence), .N, by = stop_sequence],
                     ref[trip_id == a141 & !is.na(stop_sequence), .N, by = stop_sequence])
})

test_that("gtfs2gps keeps apart stop patterns whose stop_ids would paste to the same key", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
      gtfstools::filter_by_shape_id("T2-1") |>
      filter_single_trip()
    trip <- poa$trips[1]
    st <- poa$stop_times[trip_id == trip$trip_id][order(stop_sequence)]
    xy <- poa$stops[match(st$stop_id[1:3], stop_id)]

    # pasted as "stop_sequence:stop_id" joined by "|", both trips give "1:x|2:y|2:z"
    new_stops <- data.table::data.table(stop_id = c("x|2:y", "z", "x", "y|2:z"),
                                        stop_lat = xy$stop_lat[c(1, 3, 1, 2)],
                                        stop_lon = xy$stop_lon[c(1, 3, 1, 2)])
    poa$stops <- rbind(poa$stops, new_stops, fill = TRUE)
    poa$trips <- rbind(poa$trips, data.table::copy(trip)[, trip_id := "c1"],
                       data.table::copy(trip)[, trip_id := "c2"])
    new_st <- data.table::data.table(trip_id = c("c1", "c1", "c2", "c2"),
                                     stop_id = c("x|2:y", "z", "x", "y|2:z"),
                                     stop_sequence = c(1L, 2L, 1L, 2L),
                                     arrival_time = c("08:00:00", "08:10:00", "09:00:00", "09:10:00"),
                                     departure_time = c("08:00:00", "08:10:00", "09:00:00", "09:10:00"))
    poa$stop_times <- rbind(poa$stop_times, new_st, fill = TRUE)

    res <- gtfs2gps(poa, ncores = 1, quiet = TRUE)
    out <- unique(res[trip_id %in% c("c1", "c2") & !is.na(stop_id), .(trip_id, stop_id, stop_sequence)])
    data.table::setorderv(out, c("trip_id", "stop_sequence"))
    expect_identical(out$trip_id, new_st$trip_id)
    expect_identical(out$stop_id, new_st$stop_id)
    expect_identical(out$stop_sequence, new_st$stop_sequence)
})

test_that("gtfs2gps reports infinite speeds per shape and in the returned data", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
      gtfstools::filter_by_shape_id("T2-1") |>
      filter_single_trip()
    seqs <- sort(poa$stop_times$stop_sequence)
    # the first two stops timed at the same moment: the vehicle covers the distance
    # between them in no time
    poa$stop_times[, `:=`(arrival_time = "", departure_time = "")]
    poa$stop_times[stop_sequence %in% seqs[1:2], `:=`(arrival_time = "08:00:00", departure_time = "08:00:00")]
    poa$stop_times[stop_sequence == max(seqs), `:=`(arrival_time = "09:00:00", departure_time = "09:00:00")]

    msgs <- character(0)
    res <- withCallingHandlers(gtfs2gps(poa, ncores = 1),
                               message = function(m){
                                 msgs <<- c(msgs, conditionMessage(m))
                                 invokeRestart("muffleMessage")
                               })
    n_inf <- sum(is.infinite(units::drop_units(res$speed)))
    expect_gt(n_inf, 0)
    expect_true(any(grepl(paste0("^", n_inf, " .*Inf for shape"), msgs)))
    expect_true(any(grepl("Inf in the returned data", msgs, fixed = TRUE)))
})

test_that("gtfs2gps converts a frequency-based feed", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
      gtfstools::filter_by_shape_id("T2-1") |>
      filter_single_trip()
    # one trip every 20 minutes from 08:00; end_time is exclusive, so no trip at 09:00
    poa$frequencies <- data.table::data.table(trip_id = poa$trips$trip_id[1]
                                              , start_time = "08:00:00"
                                              , end_time = "09:00:00"
                                              , headway_secs = 1200L)
    expect_identical(test_gtfs_freq(poa), "frequency")
    before <- data.table::copy(poa)

    res <- gtfs2gps(poa, ncores = 1, quiet = TRUE)

    expect_identical(poa, before)

    expect_identical(sort(unique(res$trip_number)), 1:3)
    first <- res[, .(start = timestamp[1]), by = trip_id]
    expect_identical(sort(as.character(first$start)), c("08:00:00", "08:20:00", "08:40:00"))
})
