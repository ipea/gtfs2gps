#' @title Convert GTFS shapes to simple feature object
#'
#' @description Convert the shapes of a GTFS data loaded using
#' \code{\link{read_gtfs}} into a LINESTRING simple feature (sf) object, using
#' \code{\link[gtfstools]{convert_shapes_to_sf}}, and add the length of each
#' shape in kilometres. The input data is not modified.
#' @param gtfs A GTFS data. \code{shape_id} must be character and
#' \code{shape_pt_sequence} integer, as produced by \code{\link{read_gtfs}}.
#' @param crs The coordinate reference system of the output: an EPSG code, a
#' string accepted by \code{\link[sf]{st_crs}}, or a \code{crs} object. Shapes
#' are read as WGS84 (EPSG:4326) and transformed to \code{crs}. The default
#' value is 4326 (no transformation). It must be a valid CRS: \code{NA} or an
#' unknown CRS raises an error of class \code{gtfs2gps_crs_error}.
#' @return A simple feature (sf) object with columns \code{shape_id},
#' \code{geometry} and \code{length} (km).
#' @export
#' @examples
#' poa <- read_gtfs(system.file("extdata/saopaulo.zip", package = "gtfs2gps"))
#' poa_sf <- gtfs_shapes_as_sf(poa)
gtfs_shapes_as_sf <- function(gtfs, crs = 4326){
  checkmate::assert(checkmate::check_int(crs)
                    , checkmate::check_string(crs)
                    , checkmate::check_class(crs, "crs"))
  crs <- tryCatch(suppressWarnings(sf::st_crs(crs)), error = function(e) sf::NA_crs_)
  if(is.na(crs)){
    cli::cli_abort("{.arg crs} must be a valid coordinate reference system."
                   , class = "gtfs2gps_crs_error")
  }

  gtfs <- gtfstools::as_dt_gtfs(gtfs)

  # as_dt_gtfs() returns a dt_gtfs unchanged, and gtfstools >= 2.0.0 expects
  # shapes to be a data.table. this copies shapes, not the caller's object
  if(!data.table::is.data.table(gtfs$shapes))
    gtfs$shapes <- data.table::as.data.table(gtfs$shapes)

  shapes_sf <- gtfstools::convert_shapes_to_sf(gtfs, crs = crs, sort_sequence = TRUE)

  # length of each shape
  shapes_sf$length <- units::set_units(sf::st_length(shapes_sf), "km")

  return(shapes_sf)
}

#' @title Convert GTFS stops to simple feature object
#' @description Convert a GTFS stops data loaded using gtfs2gps::read_gtf()
#' into a point simple feature (sf).
#' @param gtfs A GTFS data.
#' @param crs The coordinate reference system represented as an EPSG code.
#' The default value is 4326 (latlong WGS84)
#' @return A simple feature (sf) object.
#' @export
#' @examples
#' poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"))
#' poa_shapes <- gtfs_shapes_as_sf(poa)
#' poa_stops <- gtfs_stops_as_sf(poa)
gtfs_stops_as_sf <- function(gtfs, crs = 4326){
  temp_stops_sf <- sfheaders::sf_point(gtfs$stops, x = "stop_lon", y = "stop_lat", keep = TRUE)
  sf::st_crs(temp_stops_sf) <- crs
  return(temp_stops_sf)
}
