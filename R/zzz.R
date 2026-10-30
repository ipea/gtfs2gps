
utils::globalVariables(c(".", ":="))

.onAttach <- function(lib, pkg){
  message <- paste0(
    sprintf("gtfs2gps version %s is now loaded\n",utils::packageDescription("gtfs2gps")$Version))

  packageStartupMessage(message)
}

# NOTE: lwgeom must stay in Imports. sf::st_segmentize() on lon/lat shapes
# (used by gtfs2gps()) calls lwgeom::st_geod_segmentize() and errors without it.
# rlang is imported because cli::cli_abort(), cli_warn() and cli_inform() need it
# at runtime, while cli only suggests it.
#' @importFrom data.table := %between% fifelse %chin%
#' @importFrom utils head tail object.size
#' @importFrom lwgeom st_geod_length
#' @importFrom rlang abort
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
    'time', 'timestamp', 'i.arrival_time', 'i.route_type',
    'shape_rank', 'pattern_key', 'pattern', 'trip_rank', 'pattern_id', 'i.pattern_id',
    'point', 'k', 'status', 'ref'))
