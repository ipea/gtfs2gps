#' @title Adjust the speeds of a gps-like table created with \code{\link{gtfs2gps}} 
#'
#' @description Some GTFS.zip data sets might have quality issues, for example 
#' by assuming that a trip speed is unreasonably high (e.g. an urban bus running
#' over 100 Km/h), or in other cases the `timestamp` information might be
#' missing for some route segments. This can lead a gps-like table to have `NA`
#' or unrealistic `speed` and `timestamp` values. This function allows the
#' user to adjust the speed of trips and updates `timestamp` values 
#' accordingly. The user can adjust the problematic speeds by either setting a
#' custom constant value, or by considering the average of all valid trips speed
#' (Default). The columns `timestamp` and `cumtime` are updated accordingly.
#'
#' Each trip keeps the timestamp of its first timed point, and dwell times at
#' stops are kept, so stop timestamps don't change when every speed is within
#' range; segments whose speeds are replaced are re-timed. Trips without any
#' timestamp keep \code{NA} timestamps. Timestamps wrap at 24:00:00.
#' \code{gps_data} must be ordered as \code{\link{gtfs2gps}} returns it.
#' To cap speeds in the GTFS data before converting it, see
#' \code{\link[gtfstools]{set_max_speed}}.
#'
#' @param gps_data A GPS-like data.table created with \code{\link{gtfs2gps}}.
#' @param min_speed Minimum speed to be considered as valid. It can
#' be a numeric (in km/h) or a units value able to be converted to km/h. Values 
#' below minimum speed will be adjusted. Defaults to 2 km/h.
#' @param max_speed Maximum speed to be considered as valid. It can
#' be a numeric (in km/h) or a units value able to be converted to km/h. Values
#' above maximum speed will be adjusted. Defaults to 80 km/h.
#' @param new_speed Speed to replace missing values as well as values
#' outside min_speed and max_speed range. It can
#' be a numeric (in km/h) or a units value able to be converted to km/h.
#' By default, `new_speed = NULL` and the
#' function considers the average speed of the entire gps data.
#' @param clone Use a copy of the gps_data? Defaults to TRUE.
#' @return A GPS-like data with adjusted \code{speed} values and the same
#' columns as \code{gps_data}. The columns \code{timestamp} and \code{cumtime}
#' are also updated accordingly. An error is raised if no speed is within range
#' and \code{new_speed} is not given.
#' @export
#' @examples
#' poa <- read_gtfs(system.file("extdata/poa.zip", package="gtfs2gps")) |>
#'   gtfstools::filter_by_shape_id("T2-1") |>
#'   gtfstools::filter_by_weekday(c("monday", "wednesday")) |>
#'   filter_single_trip()
#'
#' poa_gps <- gtfs2gps(poa)
#' poa_gps_new <- adjust_speed(poa_gps)
adjust_speed <- function(gps_data, min_speed = 2, max_speed = 80, new_speed = NULL, clone = TRUE){
  if(clone) gps_data <- data.table::copy(gps_data)
  
  max_speed <- units::set_units(max_speed, "km/h") |> 
    units::set_units("m/s") |>
    units::drop_units()
  
  min_speed <- units::set_units(min_speed, "km/h") |>
    units::set_units("m/s") |>
    units::drop_units()
  
  checkmate::assert_names(names(gps_data), must.include = c("shape_id", "trip_id", "trip_number"
                                                            , "stop_sequence", "timestamp", "speed"
                                                            , "dist", "cumdist", "cumtime"))

  # work on vectors first, so that an error leaves gps_data untouched (clone = FALSE)
  spd <- units::drop_units(units::set_units(gps_data$speed, "m/s"))
  spd[!is.finite(spd)] <- NA
  stopped <- !is.na(gps_data$stop_sequence) & round(as.numeric(gps_data$dist)) == 0 & !is.na(spd)
  spd[which(!stopped & !data.table::between(spd, min_speed, max_speed))] <- NA

  if(is.null(new_speed)){
    new_speed <- stats::weighted.mean(x = spd[!stopped]
                               ,w = as.numeric(gps_data$dist)[!stopped]
                               ,na.rm=TRUE)
    if(!is.finite(new_speed))
      cli::cli_abort(c("No speed between {.arg min_speed} and {.arg max_speed} to average.",
                       "i" = "Supply {.arg new_speed} or widen the range."),
                     class = "gtfs2gps_no_valid_speed_error")
  } else {
    new_speed <- units::set_units(new_speed, "km/h") |>
      units::set_units("m/s") |>
      units::drop_units()
    if(length(new_speed) != 1 || !is.finite(new_speed) || new_speed <= 0)
      cli::cli_abort("{.arg new_speed} must be a single positive speed.",
                     class = "gtfs2gps_invalid_speed_error")
  }

  data.table::set(gps_data, j = c("speed", "stopped_bus"), value = list(spd, stopped))

  gps_data[, dist := units::drop_units(dist)]
  gps_data[, cumdist := units::drop_units(cumdist)]
  gps_data[, cumtime := units::drop_units(cumtime)]
  
  # a row that keeps its speed keeps the time gtfs2gps() gave it (the difference of
  # cumtime), so that rounded dist and speed don't move the stops; dist / speed when
  # the two disagree beyond that rounding (e.g. speed or dist changed by the user)
  gps_data[, time := {
    t <- dist / data.table::fifelse(is.na(speed), new_speed, speed)
    d <- cumtime - data.table::shift(cumtime)
    data.table::fifelse(stopped_bus,
                        data.table::fcoalesce((as.numeric(timestamp) - data.table::shift(as.numeric(timestamp))) %% 86400, 0),
                        data.table::fifelse(!is.na(speed) & !is.na(d) & abs(d - t) <= 0.002 + 1e-3 * t, d, t))
  }, by = .(shape_id, trip_id, trip_number)]

  gps_data[is.na(speed) & stopped_bus == FALSE, speed := new_speed]
  gps_data[, cumtime := cumsum(time), by = .(shape_id, trip_id, trip_number)]
  
  # anchor each trip on its own first valid timestamp
  gps_data[, timestamp := {
    k <- which(!is.na(timestamp))[1]
    if(is.na(k)) timestamp
    else data.table::as.ITime(round(as.numeric(timestamp[k]) + cumtime - cumtime[k]) %% 86400)
  }, by = .(shape_id, trip_id, trip_number)]
  
  gps_data[, speed := units::set_units(units::set_units(speed, "m/s"), "km/h")]
  gps_data[, dist := units::set_units(dist, "m")]
  gps_data[, cumdist := units::set_units(cumdist, "m")]
  gps_data[, cumtime := units::set_units(cumtime, "s")]
  
  gps_data[, c("stopped_bus", "time") := NULL]
  
  return(gps_data)
}
