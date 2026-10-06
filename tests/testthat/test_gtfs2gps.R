test_that("gtfs2gps", {
    poa <- system.file("extdata/poa.zip", package="gtfs2gps")

    poa_gps_0 <- read_gtfs(poa) |>
      adjust_arrival_departure() |>
      gtfstools::filter_by_weekday(c("monday", "tuesday", "wednesday", "thursday", "friday")) |>
      gtfs2gps(parallel = FALSE, spatial_resolution = 50)

    expect_equal(sum(units::drop_units(poa_gps_0$cumtime), na.rm = TRUE), 212843109, 0.01)
    expect_equal(sum(units::drop_units(poa_gps_0$speed), na.rm = TRUE), 3079200, 0.01)
    expect_equal(sum(units::drop_units(poa_gps_0$cumdist), na.rm = TRUE), 1447649389, 0.01)
    
    my_dim_0 <- dim(poa_gps_0)[1]
    expect_equal(my_dim_0, 128543)
    
    poa_gps <- poa_gps_0[units::drop_units(speed) > 0 & units::drop_units(cumtime) >= 0 & !is.na(speed),]
    
    my_dim <- dim(poa_gps)[1]
    expect_equal(my_dim, 126660)
    
    my_length <- length(poa_gps$dist[which(!units::drop_units(poa_gps$dist) < 50)])
    expect_equal(my_length, 0)
    
    expect_equal(sum(units::drop_units(poa_gps$dist)), 4085722, 0.1)
    
    expect_true(poa_gps$trip_number[1] == 1)
    expect_true(poa_gps$trip_number[126660] == 88)
    
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

    #poa_shape <- read_gtfs(poa) |> gtfs_shapes_as_sf()
    #plot(poa_shape)
    #poa_gps_shape <- gps_as_sf(poa_gps)
    #plot(poa_gps_shape)
    #write_sf(poa_shape, "poa_shape.shp")
    #write_sf(poa_gps_shape, "poa_gps_shape.shp")
    
    my_dim <- dim(poa_gps)[1]
    total <- 128543

    expect_equal(my_dim, total)

    poa_gps <- poa_gps[units::drop_units(speed) > 0 & units::drop_units(cumtime) > 0 & !is.na(speed) & !is.infinite(speed),]

    expect_true(all(na.omit(units::drop_units(poa_gps$speed) > 0)))
    
    my_dim <- dim(poa_gps)[1]
    expect_equal(my_dim, 126272)
    
    my_length <- length(poa_gps$dist[which(!(units::drop_units(poa_gps$dist) < 50))])
    expect_equal(my_length, 0)
    
    expect_equal(sum(units::drop_units(poa_gps$dist)), 516072, 1)

    expect_true(poa_gps$trip_number[1] == 1)
    expect_true(poa_gps$trip_number[126272] == 88)
    
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
    
    expect_equal(dim(poa_gps_30)[1], 200560)
    expect_true(dim(poa_gps_30)[1] > dim(poa_gps)[1])
    
    # save into file
    poa_simple <- read_gtfs(poa) |>
      gtfstools::filter_by_shape_id(c("T2-1", "A141-1"))

    poa_gps <- gtfs2gps(poa_simple, filepath = ".", spatial_resolution = 50)
    expect_null(poa_gps)
    
    poa_gps <- gtfs2gps(poa, filepath = ".", continue = TRUE, spatial_resolution = 50)

    expect_null(poa_gps)
    
    files1 <- list.files(".", pattern = "\\.txt$")
    names <- gsub('.{4}$', '', files1)
    
    # poa_shape <- gtfs_shapes_as_sf(read_gtfs(poa))
    # expect_setequal(poa_shape$shape_id[2:3], names[c(1,4)])

    poa_gps <- gtfs2gps(poa, filepath = ".", compress = TRUE, spatial_resolution = 50)
    
    expect_null(poa_gps)
  
    files2 <- list.files(".", pattern = "\\.rds$")
    names2 <- gsub('.{4}$', '', files2)
    
    data1 <- data.table::fread(files1[1])

    # note how the types are converted    
    data1[, timestamp := as.ITime(timestamp)]
    data1[, stop_id := as.character(stop_id)]
    data1[, trip_number := as.double(trip_number)]
    
    data2 <- readRDS(files2[1])
    
    expect_true(all(data1$trip_id == data2$trip_id))
    
    # poa_shape <- gtfs_shapes_as_sf(read_gtfs(poa))
    # expect_setequal(poa_shape$shape_id[2:3], names[c(1,4)])
    
    file.remove(files1)
    file.remove(files2)

    sp <- system.file("extdata/saopaulo.zip", package="gtfs2gps")

    expect_error(gtfs2gps(sp, continue = TRUE), "Cannot use argument 'continue' without passing a 'filepath'.", fixed = TRUE)
    expect_error(gtfs2gps(sp, compress = TRUE), "Cannot use argument 'compress' without passing a 'filepath'.", fixed = TRUE)
    

    # sp <- system.file("extdata/saopaulo.zip", package="gtfs2gps")
    # 
    # sp2 <- gtfstools::read_gtfs(sp)
    # sp3 <- gtfstools::frequencies_to_stop_times(sp2)
    # sp_gps <- sp3 |>
    #   adjust_arrival_departure()
    # 
    # gtfstools::write_gtfs(sp3, "sp3.zip")
    # 
    # sp4 <- read_gtfs("sp3.zip")
    # 
    # sp_gps <- sp4 |>
    #   gtfstools::filter_by_shape_id(52072) |>
    #  gtfstools::filter_by_weekday(c("monday", "tuesday", "wednesday", "thursday", "friday")) |>
    #   filter_single_trip() |>
    #   gtfs2gps(parallel = FALSE, spatial_resolution = 15)
    # 
    # expect_true(all(names(sp_gps) %in%
    #   c("trip_id", "route_type", "id", "shape_pt_lon", "shape_pt_lat", "trip_number",
    #     "timestamp", "stop_id", "stop_sequence", "dist", "shape_id", "cumdist", "speed", "cumtime")))
    # 
    # expect_true(all(sp_gps$trip_number %in% 1:17))
    # 
    # my_dim <- dim(sp_gps)[1]
    # total <- 287078
    # if(my_dim %in% c(261935, 265771, 274311)) total <- my_dim # Linux differences
    # 
    # expect_equal(my_dim, total)
    # 
    # expect_true(all(sp_gps$dist >= units::set_units(0, "m")))
    # expect_true(all(sp_gps$cumdist >= units::set_units(0, "m")))
    # expect_equal(length(sp_gps$speed > units::set_units(0, "km/h")), total)
    # expect_equal(length(sp_gps$cumtime > units::set_units(0, "s")), total)
    # 
    # # messages when gtfs2gps cannot convert all shapes nor all trips
    # gtfs <- read_gtfs(sp) |>
    #   gtfstools::filter_by_shape_id(52000:52200) |>
    #  gtfstools::filter_by_weekday(c("monday", "tuesday", "wednesday", "thursday", "friday")) |>
    #   filter_single_trip()
    # 
    # gtfs$stop_times <- gtfs$stop_times[-(300:390), ]
    # result <- gtfs2gps(gtfs, parallel = TRUE, spatial_resolution = 15)

    
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
    result <- gtfs2gps(poa, parallel = FALSE, quiet = TRUE)
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

test_that("gtfs2gps keeps interpolated timestamps past midnight and matches in parallel", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
      gtfstools::filter_by_shape_id("T2-1") |>
      filter_single_trip()

    # only the first and the last stop of this trip are timed; move them across midnight
    poa$stop_times[stop_sequence == min(stop_sequence),
                   `:=`(arrival_time = "23:58:00", departure_time = "23:58:00")]
    poa$stop_times[stop_sequence == max(stop_sequence),
                   `:=`(arrival_time = "24:05:00", departure_time = "24:05:00")]

    before <- data.table::copy(poa)
    seq_res <- gtfs2gps(poa, parallel = FALSE, spatial_resolution = 50, quiet = TRUE)
    expect_equal(poa, before)  # input not modified

    # interpolated rows between the two stops keep values past 86400 s (the stop
    # rows themselves are wrapped to ITime, as before)
    expect_gt(max(as.integer(seq_res$timestamp), na.rm = TRUE), 86400)

    # every row from the first stop's departure to the last stop has a speed
    # (the first stop row has no incoming segment, so it is NA)
    stop_rows <- which(!is.na(seq_res$stop_id))
    span <- stop_rows[1]:stop_rows[length(stop_rows)]
    expect_false(anyNA(seq_res$speed[span[-1]]))

    # the workers load the installed package: reinstall before relying on this
    # assertion after editing R/
    par_res <- gtfs2gps(poa, parallel = TRUE, ncores = 2, spatial_resolution = 50, quiet = TRUE)
    expect_identical(as.list(seq_res), as.list(par_res))
})

test_that("gtfs2gps skips shapes without stops or stop coordinates with a message", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
      gtfstools::filter_by_shape_id("T2-1") |>
      filter_single_trip()
    # filepath: with no output at all, the final speed checks would fail on an empty table
    out_dir <- tempfile("g2g_"); dir.create(out_dir); on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

    no_stop_times <- data.table::copy(poa)
    no_stop_times$stop_times <- no_stop_times$stop_times[0]
    expect_message(res <- gtfs2gps(no_stop_times, parallel = FALSE, filepath = out_dir),
                   "has zero stops")
    expect_null(res)

    no_stops <- data.table::copy(poa)
    no_stops$stops <- no_stops$stops[0]
    expect_message(res <- gtfs2gps(no_stops, parallel = FALSE, filepath = out_dir),
                   "no snapped stops")
    expect_null(res)

    expect_length(list.files(out_dir, pattern = "^T2-1"), 0)
})

test_that("gtfs2gps reports an error inside a worker when running in parallel", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
      gtfstools::filter_by_shape_id("T2-1") |>
      filter_single_trip()
    poa$stops[, stop_lon := NULL]  # makes the stop join inside the worker fail
    out_dir <- tempfile("g2g_"); dir.create(out_dir); on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

    expect_message(res <- gtfs2gps(poa, parallel = TRUE, ncores = 2, filepath = out_dir),
                   "Some internal bug occurred")
    expect_null(res)
    expect_length(list.files(out_dir, pattern = "^T2-1"), 0)
})

test_that("gtfs2gps converts a shape whose id is the empty string", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
      gtfstools::filter_by_shape_id("T2-1") |>
      filter_single_trip()
    ref <- gtfs2gps(poa, parallel = FALSE, spatial_resolution = 50, quiet = TRUE)

    poa$trips[, shape_id := ""]
    poa$shapes[, shape_id := ""]
    res <- gtfs2gps(poa, parallel = FALSE, spatial_resolution = 50, quiet = TRUE)

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

      gtfs2gps(poa, parallel = FALSE, filepath = out_dir, compress = compress, quiet = TRUE)
      expect_true(all(file.exists(files)))

      # a saved shape must be skipped (its file left as it is), a missing one written again
      writeLines("already saved", files[1])
      unlink(files[2])
      gtfs2gps(poa, parallel = FALSE, filepath = out_dir, compress = compress, continue = TRUE, quiet = TRUE)
      expect_identical(readLines(files[1]), "already saved")
      expect_true(file.exists(files[2]))
    }
})
