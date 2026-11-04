test_that("read_gtfs", {
  expect_error(read_gtfs("xyz123.zip"))
  
  poa <- read_gtfs(system.file("extdata/poa.zip", package="gtfs2gps"))
  
  expect_type(poa, "list")
  expect_equal(length(poa), 7)
  
  expect_true(length(poa$agency) >= 1)
  expect_equal(length(poa$routes), 9)
  expect_equal(length(poa$stops), 6)
  expect_equal(length(poa$stop_times), 5)
  expect_equal(length(poa$shapes), 4)
  expect_equal(length(poa$trips), 4)
  expect_equal(length(poa$calendar), 10)
  
  expect_type(poa$stop_times$arrival_time, "character")
  expect_type(poa$stop_times$departure_time, "character")
  
  expect_equal(dim(poa$stop_times)[1], 23040)
  expect_equal(dim(poa$shapes)[1], 1265)
  expect_equal(dim(poa$trips)[1], 387)
  
  sp <- read_gtfs(system.file("extdata/saopaulo.zip", package="gtfs2gps"))
  
  expect_type(sp$frequencies$start_time, "character")
  expect_type(sp$frequencies$end_time, "character")
})

test_that("read_gtfs accepts optional routes fields and a header-only frequencies.txt", {
  feed <- gtfstools::read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE)
  feed$routes[, c("agency_id", "route_short_name") := NULL]
  feed$frequencies <- data.table::data.table(trip_id = character(), start_time = character(),
                                             end_time = character(), headway_secs = integer())
  path <- tempfile(fileext = ".zip")
  on.exit(unlink(path), add = TRUE)
  gtfstools::write_gtfs(feed, path, quiet = TRUE)

  poa <- read_gtfs(path, quiet = TRUE)

  expect_false("agency_id" %in% names(poa$routes))
  expect_null(poa$frequencies)
  expect_equal(test_gtfs_freq(poa), "simple")
})
