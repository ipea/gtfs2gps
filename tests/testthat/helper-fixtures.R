# poa T2-1, one trip, whose only two timed stops (the first and the last) are moved
# across midnight: 23:40:00 to 24:20:00
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
