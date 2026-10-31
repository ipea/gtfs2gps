
test_that("append_height", {
  fortaleza <- system.file("extdata/fortaleza.zip", package="gtfs2gps")
  srtmfile <- system.file("extdata/fortaleza-srtm.tif", package="gtfs2gps")
  
  gtfs <- read_gtfs(fortaleza) |>
    gtfstools::filter_by_shape_id("shape804-I") |>
    filter_single_trip() |>
    gtfstools::remove_unused_ids()
  
  fortaleza_gps <- gtfs2gps(gtfs, spatial_resolution = 500) |> append_height(srtmfile)

  mysum <- sum(fortaleza_gps$height)

  expect_equal(mysum, 3314, 0.05)

  # heightfile must be an existing file
  expect_error(append_height(fortaleza_gps, "no_such_file.tif"), "heightfile")

  #fort <- fortaleza_gps[which(is.na(fortaleza_gps$height)),]
  
  #fott <- gps_as_sf(fort)
  #sf::write_sf(fott, "fort-na.shp")  
})
