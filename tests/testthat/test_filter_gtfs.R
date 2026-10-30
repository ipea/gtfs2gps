
test_that("filter_valid_stop_times", {
  poa <- read_gtfs(system.file("extdata/poa.zip", package="gtfs2gps"))
  
  expect_equal(dim(poa$stop_times)[1], 23040)
  expect_equal(dim(poa$stops)[1], 212)
  expect_equal(dim(poa$routes)[1], 4)
  
  expect_warning(subset <- filter_valid_stop_times(poa), "filter_valid_stop_times.*is deprecated")
  expect_equal(dim(subset$stop_times)[1], 774)
  expect_equal(dim(subset$stops)[1], 8)
  expect_equal(dim(subset$routes)[1], 4)
})


test_that("remove_invalid", {
  sp <- read_gtfs(system.file("extdata/saopaulo.zip", package="gtfs2gps"))

  sp$shapes <- sp$shapes[-(1:30000),]
  sp$agency$agency_id <- 'test'
  
  expect_warning(sp2 <- remove_invalid(sp, prompt_invalid = TRUE), "remove_invalid.*is deprecated")
  
  expect_equal(length(sp$stops$stop_id), 3039)
  expect_equal(length(sp2$stops$stop_id), 602)
  
  sp3 <- suppressWarnings(remove_invalid(sp, only_essential = FALSE))

  expect_equal(length(sp3$stops$stop_id), 0)
})

test_that("remove_invalid lists every removed id", {
  sp <- read_gtfs(system.file("extdata/saopaulo.zip", package = "gtfs2gps"), quiet = TRUE)
  sp$shapes <- sp$shapes[-(1:30000), ]

  msgs <- character()
  withCallingHandlers(suppressWarnings(remove_invalid(sp, prompt_invalid = TRUE)),
                      message = function(m){
                        msgs <<- c(msgs, conditionMessage(m))
                        invokeRestart("muffleMessage")
                      })

  # 79 shape ids are removed; cli would otherwise cut the list after 20
  shape_msg <- grep("shape_ids removed", msgs, value = TRUE)
  expect_length(shape_msg, 1)
  expect_false(grepl("…|\\.\\.\\.", shape_msg))
  expect_true(grepl("52421", shape_msg) && grepl("^79 ", shape_msg))
})

test_that("filter_single_trip ignores trips without a shape", {
  poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE)
  first <- poa$trips$trip_id[1]
  poa$trips[1, shape_id := NA_character_]

  single <- filter_single_trip(poa)

  expect_false(first %in% single$trips$trip_id)
  expect_false(anyNA(single$trips$shape_id))
})

test_that("remove_invalid keeps services from either calendar table and timetabled trips", {
  poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE)
  n_trips <- nrow(poa$trips)

  # a service listed in calendar but not in calendar_dates is still valid
  poa$calendar_dates <- data.table::data.table(service_id = "X", date = as.Date("2024-01-01"),
                                               exception_type = 1L)
  expect_equal(nrow(suppressWarnings(remove_invalid(poa, only_essential = FALSE))$trips), n_trips)

  # trips without a frequencies entry are timetabled trips, not invalid ones
  sp <- read_gtfs(system.file("extdata/saopaulo.zip", package = "gtfs2gps"), quiet = TRUE)
  sp_trips <- nrow(suppressWarnings(remove_invalid(sp))$trips)
  sp$frequencies <- sp$frequencies[trip_id %chin% sp$trips$trip_id[1:10]]
  expect_equal(nrow(suppressWarnings(remove_invalid(sp))$trips), sp_trips)

  # single-agency feed whose routes have no agency_id
  poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"), quiet = TRUE)
  poa$agency <- poa$agency[1]
  poa$routes[, agency_id := NA_character_]
  expect_equal(nrow(suppressWarnings(remove_invalid(poa, only_essential = FALSE))$trips), n_trips)
})

test_that("filter_valid_stop_times drops malformed times and keeps strings verbatim", {
  poa <- read_gtfs(system.file("extdata/poa.zip", package="gtfs2gps"))

  poa$stop_times[1, `:=`(arrival_time = "05:21", departure_time = "05:21:00")]
  poa$stop_times[2, `:=`(arrival_time = "abc", departure_time = "05:21:00")]
  poa$stop_times[3, `:=`(arrival_time = " 5:21:00", departure_time = "5:21:00")]
  poa$stop_times[4, `:=`(arrival_time = "05:75:00", departure_time = "05:75:00")]
  keys <- poa$stop_times[1:4, .(trip_id, stop_sequence)]
  before <- data.table::copy(poa)

  subset <- suppressWarnings(filter_valid_stop_times(poa))

  # input data is not modified
  expect_identical(poa, before)

  # rows 1, 2 and 4 dropped, row 3 kept with its strings untouched
  kept <- subset$stop_times[keys, on = c("trip_id", "stop_sequence"), nomatch = NULL]
  expect_equal(nrow(kept), 1)
  expect_equal(kept$arrival_time, " 5:21:00")
  expect_equal(kept$departure_time, "5:21:00")
})
