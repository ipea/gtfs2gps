#' @title Write GTFS data into a zip file
#' @description Write GTFS stored in memory as a list of data.tables into a
#' zipped GTFS feed, using \code{\link[gtfstools]{write_gtfs}}. By default an
#' existing zip file is overwritten; set \code{overwrite = FALSE} to raise an
#' error instead.
#' @param gtfs A GTFS data set stored in memory as a list of data.tables/data.frames.
#' @param zipfile The pathname of a .zip file to be saved with the GTFS data.
#' @param overwrite A logical. Whether to overwrite an existing \code{.zip} file.
#'        If \code{FALSE} and \code{zipfile} already exists, an error is
#'        raised. Defaults to \code{TRUE}.
#' @param quiet A logical. Whether to hide log messages and progress bars. 
#'        Defaults to \code{FALSE}.
#' @param compression_level A whole number from 1 (fastest) to 9 (smallest
#'        file). The compression level of the zip file. Defaults to 6.
#'
#' @return The GTFS data, invisibly.
#' 
#' @export
#' 
#' @examples
#' 
#' # read a gtfs.zip to memory
#' poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps")) |>
#'   gtfstools::filter_by_shape_id("T2-1") |>
#'   filter_single_trip()
#' 
#' # write GTFS data into a zip file
#' write_gtfs(poa, paste0(tempdir(), "/mypoa.zip"))
#' 
write_gtfs <- function(gtfs, zipfile, overwrite = TRUE, quiet = FALSE, compression_level = 6){

  checkmate::assert_string(zipfile)
  checkmate::assert_flag(overwrite)
  checkmate::assert_flag(quiet)
  checkmate::assert_int(compression_level, lower = 1, upper = 9)

  if(!overwrite && file.exists(zipfile)){
    cli::cli_abort(
      c("{.file {zipfile}} already exists.",
        "i" = "Use {.code overwrite = TRUE} to replace it."),
      class = "gtfs2gps_file_exists_error"
    )
  }

  gtfstools::write_gtfs(gtfs = gtfs, 
                      path = zipfile, 
                      overwrite = overwrite,
                      quiet = quiet,
                      compression_level = compression_level
  )
}