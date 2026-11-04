#' @title Convert GPS-like data.table to a Simple Feature points object
#' 
#' @description Convert a GPS data stored in a data.table into Simple Feature points.
#'
#' @param gps A data.table with timestamp data.
#' @param crs The coordinate reference system of the output, as accepted by
#' \code{\link[sf]{st_crs}}. Points are read as WGS84 (EPSG:4326) and
#' transformed to \code{crs}. The default value is 4326 (no transformation).
#' @return A simple feature (sf) object with point data.
#' @export
#' @examples
#' library(gtfs2gps)
#' 
#' fortaleza <- read_gtfs(system.file("extdata/fortaleza.zip", package = "gtfs2gps"))
#' srtmfile <- system.file("extdata/fortaleza-srtm.tif", package="gtfs2gps")
#'
#' subset <- fortaleza |>
#'   gtfstools::filter_by_weekday(c("monday", "wednesday")) |>
#'   filter_single_trip() |>
#'   gtfstools::filter_by_shape_id("shape806-I")
#' 
#' for_gps <- gtfs2gps(subset)
#' for_gps_sf_points <- gps_as_sfpoints(for_gps)
gps_as_sfpoints <- function(gps, crs = 4326){
  checkmate::assert_data_frame(gps, min.rows = 1)

  if(is.null(gps$height))
    temp_gps <- sfheaders::sf_point(gps, x = "shape_pt_lon", y = "shape_pt_lat", keep = TRUE)
  else
    temp_gps <- sfheaders::sf_point(gps, x = "shape_pt_lon", y = "shape_pt_lat", z = "height", keep = TRUE)

  # points are in WGS84; transform them to crs
  sf::st_crs(temp_gps) <- 4326
  temp_gps <- sf::st_transform(temp_gps, crs)
  return(temp_gps)
}
