#' @title Convert GTFS shapes to simple feature object
#'
#' @description Convert the shapes of a GTFS data loaded using
#' \code{\link{read_gtfs}} into a LINESTRING simple feature (sf) object, using
#' \code{\link[gtfstools]{get_shapes_geometry}}, and add the length of each
#' shape in kilometres, using \code{\link[gtfstools]{get_shape_length}}. The
#' input data is not modified.
#' @param gtfs A GTFS data. \code{shape_id} must be character and
#' \code{shape_pt_sequence} integer, as produced by \code{\link{read_gtfs}}.
#' @param crs The coordinate reference system of the output: an EPSG code, a
#' string accepted by \code{\link[sf]{st_crs}}, or a \code{crs} object. Shapes
#' are read as WGS84 (EPSG:4326) and transformed to \code{crs}. The default
#' value is 4326 (no transformation). Other inputs (e.g. \code{NA}) raise an
#' error, and an empty or unknown CRS raises an error of class
#' \code{gtfs2gps_crs_error}.
#' @return A simple feature (sf) object with columns \code{shape_id},
#' \code{geometry} and \code{length} (km). The length is computed from the
#' WGS84 points of each shape, whatever \code{crs} is.
#' @export
#' @examples
#' poa <- read_gtfs(system.file("extdata/saopaulo.zip", package = "gtfs2gps"))
#' poa_sf <- gtfs_shapes_as_sf(poa)
gtfs_shapes_as_sf <- function(gtfs, crs = 4326){
  crs <- as_valid_crs(crs)

  gtfs <- gtfstools::as_dt_gtfs(gtfs)

  # as_dt_gtfs() returns a dt_gtfs unchanged, and gtfstools expects shapes to
  # be a data.table. this copies shapes, not the caller's object
  if(!data.table::is.data.table(gtfs$shapes))
    gtfs$shapes <- data.table::as.data.table(gtfs$shapes)

  shapes_sf <- gtfstools::get_shapes_geometry(gtfs, crs = crs)

  # length of each shape, from the WGS84 points
  len <- gtfstools::get_shape_length(gtfs, unit = "km")
  shapes_sf$length <- units::set_units(len$length[match(shapes_sf$shape_id, len$shape_id)], "km")

  return(shapes_sf)
}

#' @title Convert GTFS stops to simple feature object
#' @description Convert the stops of a GTFS data loaded using
#' \code{\link{read_gtfs}} into a POINT simple feature (sf) object, using
#' \code{\link[gtfstools]{get_stops_geometry}}. The input data is not modified.
#' @param gtfs A GTFS data. \code{stop_id} must be character and
#' \code{stop_lon} and \code{stop_lat} numeric, as produced by
#' \code{\link{read_gtfs}}.
#' @param crs The coordinate reference system of the output: an EPSG code, a
#' string accepted by \code{\link[sf]{st_crs}}, or a \code{crs} object. Stops
#' are read as WGS84 (EPSG:4326) and transformed to \code{crs}. The default
#' value is 4326 (no transformation). Other inputs (e.g. \code{NA}) raise an
#' error, and an empty or unknown CRS raises an error of class
#' \code{gtfs2gps_crs_error}.
#' @return A simple feature (sf) object.
#' @export
#' @examples
#' poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"))
#' poa_shapes <- gtfs_shapes_as_sf(poa)
#' poa_stops <- gtfs_stops_as_sf(poa)
gtfs_stops_as_sf <- function(gtfs, crs = 4326){
  crs <- as_valid_crs(crs)

  gtfs <- gtfstools::as_dt_gtfs(gtfs)

  # as for shapes in gtfs_shapes_as_sf(): a dt_gtfs may still hold a data.frame
  if(!data.table::is.data.table(gtfs$stops))
    gtfs$stops <- data.table::as.data.table(gtfs$stops)

  return(gtfstools::get_stops_geometry(gtfs, crs = crs))
}

#' A crs argument as an sf crs object
#'
#' Accepts an EPSG code, a string accepted by sf::st_crs() or a crs object, as
#' gtfstools accepts only numbers and crs objects. NA or an unknown CRS raises
#' an error of class gtfs2gps_crs_error.
#' @noRd
as_valid_crs <- function(crs){
  checkmate::assert(checkmate::check_int(crs)
                    , checkmate::check_string(crs)
                    , checkmate::check_class(crs, "crs"))
  crs <- tryCatch(suppressWarnings(sf::st_crs(crs)), error = function(e) sf::NA_crs_)
  if(is.na(crs)){
    cli::cli_abort("{.arg crs} must be a valid coordinate reference system."
                   , class = "gtfs2gps_crs_error"
                   , call = rlang::caller_env())
  }
  return(crs)
}
