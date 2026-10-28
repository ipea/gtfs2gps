
test_that("gps_as_sflinestring", {
  fortaleza <- read_gtfs(system.file("extdata/fortaleza.zip", package = "gtfs2gps"))

  subset <- fortaleza |>
    gtfstools::filter_by_weekday(c("monday", "tuesday", "wednesday", "thursday", "friday")) |>
    filter_single_trip() |>
    gtfstools::filter_by_shape_id(c("shape804-I", "shape806-I"))
  
  for_gps <- gtfs2gps(subset) |> adjust_speed()

  for_gps_sf_lines <- gps_as_sflinestring(for_gps)
  for_gps_sf_lines
  expect_true(is(for_gps_sf_lines, "sf"))

  expect_equal(dim(for_gps_sf_lines)[1], 41)
  expect_equal(for_gps_sf_lines$from_stop_id[1], "2649")
  expect_equal(length(names(for_gps_sf_lines)), 15)

  # -----
  # test to fix NA values
  gps <- read_gtfs(system.file("extdata/poa.zip", package="gtfs2gps")) |>
    gtfstools::filter_by_shape_id("176-1") |>
    filter_single_trip() |>
    gtfs2gps() |>
    adjust_speed() |>
    gps_as_sflinestring()
  expect_equal(max(units::drop_units(gps$cumtime)), 3124.563, tolerance = 0.001)

})

test_that("gps_as_sflinestring splits at every stop and keeps times", {
  poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE)

  # the roxygen example: 89 stop-to-stop segments, plus a first and a last
  # segment ("-") for each of the 2 trips
  ex <- gtfstools::filter_by_shape_id(poa, c("T2-1", "A141-1")) |>
    filter_single_trip() |>
    gtfs2gps(parallel = FALSE, quiet = TRUE) |>
    gps_as_sflinestring()
  expect_equal(nrow(ex), 93)
  expect_equal(sum(ex$from_stop_id != "-" & ex$to_stop_id != "-"), 89)
  expect_false(anyNA(ex$cumtime))

  # a file written from the GPS data gives the same result
  gps <- gtfstools::filter_by_shape_id(poa, "176-1") |>
    filter_single_trip() |>
    gtfs2gps(parallel = FALSE, quiet = TRUE)
  gps_adj <- adjust_speed(gps)
  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f), add = TRUE)
  data.table::fwrite(gps_adj, f)
  from_memory <- gps_as_sflinestring(gps_adj)
  from_file <- gps_as_sflinestring(f)
  expect_equal(sf::st_drop_geometry(from_file), sf::st_drop_geometry(from_memory),
               check.attributes = FALSE)
  expect_equal(sf::st_geometry(from_file), sf::st_geometry(from_memory))

  # missing times inside a trip are not turned into zero
  i <- which(!is.na(gps$stop_id))[5]
  gps[(i - 3):(i + 3), `:=`(timestamp = NA, speed = NA)]
  expect_true(anyNA(gps_as_sflinestring(gps)$cumtime))
})

test_gtfs_midnight <- function(){
  poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE) |>
    gtfstools::filter_by_shape_id("T2-1") |>
    filter_single_trip()
  poa$stop_times[stop_sequence == min(stop_sequence),
                 `:=`(arrival_time = "23:40:00", departure_time = "23:40:00")]
  poa$stop_times[stop_sequence == max(stop_sequence),
                 `:=`(arrival_time = "24:20:00", departure_time = "24:20:00")]
  return(poa)
}

test_that("gps_as_sflinestring timestamps wrap at midnight", {
  lines <- gtfs2gps(test_gtfs_midnight(), parallel = FALSE, quiet = TRUE) |>
    gps_as_sflinestring()

  ts <- as.integer(c(lines$from_timestamp, lines$to_timestamp))
  expect_true(all(ts >= 0 & ts < 86400, na.rm = TRUE))
  expect_true(any(ts < 3600, na.rm = TRUE))
})
