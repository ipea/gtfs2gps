test_that("gtfs_shape_as_sf", {
    # pinned lengths are spherical (s2); make the test independent of the session
    old_s2 <- suppressMessages(sf::sf_use_s2(TRUE))
    on.exit(suppressMessages(sf::sf_use_s2(old_s2)), add = TRUE)

    poa <- read_gtfs(system.file("extdata/poa.zip", package="gtfs2gps"))

    poa_sf <- gtfs_shapes_as_sf(poa)

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

    expect_s3_class(gtfs_shapes_as_sf(poa_df), "sf")
    expect_identical(poa_df, before)
    expect_false(data.table::is.data.table(poa_df$shapes))

    # a dt_gtfs with unsorted shapes is not reordered in place
    poa_rev <- data.table::copy(poa)
    poa_rev$shapes <- poa_rev$shapes[order(-shape_pt_sequence)]
    before <- data.table::copy(poa_rev)
    expect_s3_class(gtfs_shapes_as_sf(poa_rev), "sf")
    expect_identical(poa_rev, before)

    # plain list (no gtfs class) and character crs
    expect_s3_class(gtfs_shapes_as_sf(unclass(poa)), "sf")
    expect_s3_class(gtfs_shapes_as_sf(poa, crs = "EPSG:4326"), "sf")
})

test_that("gtfs_shapes_as_sf transforms to crs", {
    poa <- read_gtfs(system.file("extdata/poa.zip", package="gtfs2gps"))

    poa_utm <- gtfs_shapes_as_sf(poa, crs = 31982)

    expect_equal(sf::st_crs(poa_utm), sf::st_crs(31982))
    expect_true(all(abs(sf::st_coordinates(poa_utm)[, 1]) > 1000))

    expect_error(gtfs_shapes_as_sf(poa, crs = NA))
    expect_error(gtfs_shapes_as_sf(poa, crs = NULL))
    expect_error(gtfs_shapes_as_sf(poa, crs = sf::NA_crs_), class = "gtfs2gps_crs_error")
    expect_error(gtfs_shapes_as_sf(poa, crs = "garbage"), class = "gtfs2gps_crs_error")
})

test_that("gtfs_stops_as_sf", {
  poa <- read_gtfs(system.file("extdata/poa.zip", package="gtfs2gps"))

  poa_sf <- gtfs_stops_as_sf(poa)

  expect_true(inherits(poa_sf, "sf"))
  expect_equal(dim(poa_sf)[1], 212)
  expect_equal(sf::st_crs(poa_sf), sf::st_crs(4326))

  # crs transforms the points instead of relabelling the degrees
  poa_utm <- gtfs_stops_as_sf(poa, crs = 31982)
  expect_equal(sf::st_crs(poa_utm), sf::st_crs(31982))
  expect_equal(sf::st_coordinates(poa_utm), sf::st_coordinates(sf::st_transform(poa_sf, 31982)))
})
