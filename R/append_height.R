#' @title Add a column with height to GPS data
#' @description Add a column named height to GPS data using a tif data as reference.
#' @param gps A GPS data created from gtfs2gps().
#' @param heightfile The pathname of a tif file with height data.
#' @return The GPS data with a new column named height.
#' @export
#' @examples
#' \donttest{
#' fortaleza <- system.file("extdata/fortaleza.zip", package = "gtfs2gps")
#' srtmfile <- system.file("extdata/fortaleza-srtm.tif", package = "gtfs2gps")
#'
#' gtfs <- read_gtfs(fortaleza) |>
#'   gtfstools::filter_by_shape_id("shape836-I") |>
#'   filter_single_trip()
#'
#' fortaleza_gps <- gtfs2gps(gtfs, spatial_resolution = 500, parallel = FALSE, quiet = TRUE) |>
#'   append_height(srtmfile)
#' }
append_height <- function(gps, heightfile){
  checkmate::assert_file_exists(heightfile)
  myraster <- terra::rast(heightfile)
  result <-  terra::extract(myraster, gps[, c("shape_pt_lon", "shape_pt_lat")])
  gps$height <- result[, 2]
  return(gps)
}
