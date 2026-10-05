
utils::globalVariables(c(".", ":="))
.onLoad <- function(lib, pkg) {
  # Use GForce Optimisations in data.table operations
  # details > https://jangorecki.gitlab.io/data.cube/library/data.table/html/datatable-optimize.html
  options(datatable.optimize = Inf) # nocov
  
  # set number of threads used in data.table to 100% 
  data.table::setDTthreads(percent = 100) # nocov
}

.onAttach <- function(lib, pkg){
  message <- paste0(
    sprintf("gtfs2gps version %s is now loaded\n",utils::packageDescription("gtfs2gps")$Version))

  packageStartupMessage(message)
}

# NOTE: lwgeom must stay in Imports. sf::st_segmentize() on lon/lat shapes
# (used by gtfs2gps()) calls lwgeom::st_geod_segmentize() and errors without it.
#' @importFrom data.table := %between% fifelse %chin%
#' @importFrom stats na.omit
#' @importFrom utils head tail object.size
#' @importFrom Rcpp compileAttributes
#' @importFrom lwgeom st_geod_length
#' @useDynLib gtfs2gps, .registration = TRUE
NULL

## quiets concerns of R CMD check re: the .'s that appear in pipelines
if(getRversion() >= "2.15.1") utils::globalVariables(
  c('dist', 'shape_id', 'route_id', 'trip_id', 'stop_id', 'to_stop_id',
    'service_id', 'stop_sequence', 'agency_id', 'i.stop_lat', 'i.stop_lon', 'i.stop_id',
    'departure_time', 'arrival_time', 'departure_time_secs', 'arrival_time_secs', 'i.stop_sequence',
    'shape_pt_lon', 'shape_pt_lat', 'id', 'cumdist', 'i.departure_time',
    '.N', 'shape_pt_sequence', 'geometry',
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
    'cumtime', 'speed', 'i', 'route_type', 'trip_number', 'mdate',
    '.I', 'interval_id', 'i.interval', '.SD', 'grp', '.GRP','stopped_bus', 'weighted.mean',
    'N_intervals', 'as.ITime', 'from_stop_id', 'from_timestamp', 'i.from_stop_id',
    'i.from_timestamp', 'i.interval_status', 'i.shape_id', 'i.to_stop_id',
    'i.to_timestamp', 'interval_status', 'numbers', 'to_timestamp',
    'time', 'timestamp', 'i.arrival_time', 'i.route_type'))
