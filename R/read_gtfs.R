#' @title Read GTFS data into a list of data.tables
#' @description Read files of a zipped GTFS feed and load them to memory as a list of data.tables.
#' It will load the following files: "shapes.txt", "stop_times.txt", "stops.txt", "trips.txt",
#' "agency.txt", "calendar.txt", "routes.txt", and "frequencies.txt", with
#' this last four being optional. If one of the mandatory files is missing or
#' empty, this function raises an error of class \code{gtfs2gps_empty_file_error}.
#' An empty "frequencies.txt" is dropped.
#' @param gtfszip A zipped GTFS data.
#' @param quiet A logical. Whether to hide log messages and progress bars. 
#'              Defaults to `FALSE`.
#'              
#' @return A list of data.tables, where each index represents the respective GTFS file name.
#' 
#' @export
#' 
#' @examples
#' poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"))
#' 
read_gtfs <- function(gtfszip, quiet = FALSE){
  # read GTFS feed
  result <- 
    gtfstools::read_gtfs(
      path = gtfszip,
      quiet = quiet,
      # files = c("agency", "routes", "stops", "stop_times", "shapes", "trips", "calendar", "calendar_dates", "frequencies"),
      fields = list(
        #stops = c("stop_id", "stop_lat", "stop_lon"),
        stop_times = c("trip_id", "arrival_time", "departure_time", "stop_id", "stop_sequence"),
        shapes = c("shape_id", "shape_pt_lat", "shape_pt_lon", "shape_pt_sequence"),
        trips = c("route_id", "service_id", "trip_id", "shape_id")
      )
    )

  # check columns
  for(file in c("shapes", "trips", "stops", "stop_times")){
    if(is.null(result[[file]]) || nrow(result[[file]]) == 0)
      cli::cli_abort("{.file {file}.txt} is empty or missing in the GTFS file.",
                     class = "gtfs2gps_empty_file_error")
  }

  # a header-only frequencies.txt is valid GTFS: the feed has no frequencies
  if(!is.null(result$frequencies) && nrow(result$frequencies) == 0)
    result$frequencies <- NULL

  return(result)
}