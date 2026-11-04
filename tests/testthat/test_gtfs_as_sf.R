# gtfs_stops_as_sf() is deprecated: muffle only its deprecation warning, so
# that other warnings still surface
stops_as_sf_quiet <- function(...){
  withCallingHandlers(gtfs_stops_as_sf(...),
                      deprecated_gtfs_stops_as_sf = function(w) invokeRestart("muffleWarning"))
}

test_that("gtfs_shape_as_sf", {
    # pinned lengths are spherical (s2); make the test independent of the session
    old_s2 <- suppressMessages(sf::sf_use_s2(TRUE))
    on.exit(suppressMessages(sf::sf_use_s2(old_s2)), add = TRUE)

    poa <- read_gtfs(system.file("extdata/poa.zip", package="gtfs2gps"))

    poa_sf <- shapes_as_sf(poa)

    expect_true(inherits(poa_sf, "sf"))
    expect_equal(dim(poa_sf)[1], 4)

    expect_true("length" %in% names(poa_sf))
    expect_equal(names(poa_sf), c("shape_id", "geometry", "length"))

    # geodesic lengths in km (WGS84)
    expect_equal(as.numeric(poa_sf$length),
                 c(23.461860, 6.951862, 26.725668, 17.175825), 1e-6)
    expect_equal(as.character(units(poa_sf$length)), "km")
})

test_that("gtfs_shapes_as_sf does not change the input and accepts plain lists", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package="gtfs2gps"))

    # a shapes data.frame stays a data.frame
    poa_df <- poa
    poa_df$shapes <- as.data.frame(poa_df$shapes)
    before <- data.table::copy(poa_df)

    expect_s3_class(shapes_as_sf(poa_df), "sf")
    expect_identical(poa_df, before)
    expect_false(data.table::is.data.table(poa_df$shapes))

    # a dt_gtfs with unsorted shapes is not reordered in place
    poa_rev <- data.table::copy(poa)
    poa_rev$shapes <- poa_rev$shapes[order(-shape_pt_sequence)]
    before <- data.table::copy(poa_rev)
    expect_s3_class(shapes_as_sf(poa_rev), "sf")
    expect_identical(poa_rev, before)

    # plain list (no gtfs class) and character crs
    expect_s3_class(shapes_as_sf(unclass(poa)), "sf")
    expect_s3_class(shapes_as_sf(poa, crs = "EPSG:4326"), "sf")
})

test_that("gtfs_shapes_as_sf transforms to crs", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package="gtfs2gps"))

    poa_utm <- shapes_as_sf(poa, crs = 31982)

    expect_equal(sf::st_crs(poa_utm), sf::st_crs(31982))
    expect_true(all(abs(sf::st_coordinates(poa_utm)[, 1]) > 1000))

    expect_error(shapes_as_sf(poa, crs = NA))
    expect_error(shapes_as_sf(poa, crs = NULL))
    expect_error(shapes_as_sf(poa, crs = sf::NA_crs_), class = "gtfs2gps_crs_error")
    expect_error(shapes_as_sf(poa, crs = "garbage"), class = "gtfs2gps_crs_error")
})

test_that("gtfs_stops_as_sf", {
  poa <- read_gtfs(system.file("extdata/poa.zip", package="gtfs2gps"))

  poa_sf <- stops_as_sf_quiet(poa)

  expect_true(inherits(poa_sf, "sf"))
  expect_equal(dim(poa_sf)[1], 212)
  expect_equal(sf::st_crs(poa_sf), sf::st_crs(4326))

  # crs transforms the points instead of relabelling the degrees
  poa_utm <- stops_as_sf_quiet(poa, crs = 31982)
  expect_equal(sf::st_crs(poa_utm), sf::st_crs(31982))
  expect_equal(sf::st_coordinates(poa_utm), sf::st_coordinates(sf::st_transform(poa_sf, 31982)))

  # crs as a string or a crs object gives the same transform
  expect_equal(sf::st_coordinates(stops_as_sf_quiet(poa, crs = "EPSG:31982")), sf::st_coordinates(poa_utm))
  expect_equal(sf::st_coordinates(stops_as_sf_quiet(poa, crs = sf::st_crs(31982))), sf::st_coordinates(poa_utm))
  expect_error(stops_as_sf_quiet(poa, crs = "garbage"), class = "gtfs2gps_crs_error")
  expect_equal(sf::st_coordinates(stops_as_sf_quiet(poa, crs = sf::st_crs(4326))), sf::st_coordinates(poa_sf))

  # empty stops give an empty sf object
  poa_empty <- data.table::copy(poa)
  poa_empty$stops <- poa_empty$stops[0]
  expect_equal(nrow(stops_as_sf_quiet(poa_empty)), 0)
})

test_that("gtfs_stops_as_sf accepts plain lists and data.frames and does not change the input", {
  poa <- read_gtfs(system.file("extdata/poa.zip", package="gtfs2gps"))

  expect_equal(nrow(stops_as_sf_quiet(unclass(poa))), 212)

  # a dt_gtfs whose stops is a data.frame
  poa_df <- poa
  poa_df$stops <- as.data.frame(poa_df$stops)
  before <- data.table::copy(poa_df)
  expect_equal(nrow(stops_as_sf_quiet(poa_df)), 212)
  expect_equal(poa_df, before)

  # stop_id must be character, as read_gtfs() produces
  poa_int <- data.table::copy(poa)
  poa_int$stops[, stop_id := seq_len(.N)]
  expect_error(stops_as_sf_quiet(poa_int), "stop_id")
})

test_that("gtfs_shapes_as_sf length does not depend on crs", {
  poa <- read_gtfs(system.file("extdata/poa.zip", package="gtfs2gps"))

  expect_equal(shapes_as_sf(poa, crs = 31982)$length, shapes_as_sf(poa)$length)
})

test_that("gtfs_shapes_as_sf and gtfs_stops_as_sf are deprecated", {
  poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE)

  expect_warning(gtfs_shapes_as_sf(poa), class = "deprecated_gtfs_shapes_as_sf")
  expect_identical(suppressWarnings(gtfs_shapes_as_sf(poa, crs = 31982)), shapes_as_sf(poa, crs = 31982))
  expect_warning(gtfs_stops_as_sf(poa), class = "deprecated_gtfs_stops_as_sf")

  # an invalid crs error names the exported function, not the internal one
  err <- tryCatch(suppressWarnings(gtfs_shapes_as_sf(poa, crs = "garbage")),
                  gtfs2gps_crs_error = function(e) e)
  expect_s3_class(err, "gtfs2gps_crs_error")
  expect_identical(deparse(conditionCall(err)[[1]]), "gtfs_shapes_as_sf")
})
