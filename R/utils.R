


# An H:MM:SS GTFS time (hours may exceed 24; minutes and seconds below 60, as in
# gtfstools::convert_time_to_seconds()). Used by filter_valid_stop_times().
valid_gtfs_time <- "^[0-9]+:[0-5][0-9]:[0-5][0-9]$"

#' Convert stop_times time strings to seconds after midnight
#'
#' Replaces the \code{arrival_time} and \code{departure_time} columns of
#' \code{gtfs$stop_times} with integer seconds after midnight, using
#' \code{gtfstools::convert_time_to_seconds()}, which turns malformed strings
#' into \code{NA} with a warning of class \code{gtfstools_malformed_time}.
#' The conversion is done in place, so callers must copy first.
#'
#' @param gtfs A GTFS object (a list of data.tables). Plain lists are promoted
#'   with \code{gtfstools::as_dt_gtfs()}, which copies every table.
#'
#' @return The GTFS object, with integer time columns in \code{stop_times}.
#'
#' @noRd
stop_times_to_seconds <- function(gtfs) {

  gtfs <- gtfstools::convert_time_to_seconds(
    gtfstools::as_dt_gtfs(gtfs),
    file = "stop_times",
    by_reference = TRUE
  )

  gtfs$stop_times[, `:=`(
    departure_time = departure_time_secs
    , arrival_time = arrival_time_secs
    , departure_time_secs = NULL
    , arrival_time_secs = NULL)]

  return(gtfs)

}
