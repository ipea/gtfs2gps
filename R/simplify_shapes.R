
#' @title Simplify shapes of a GTFS file
#'
#' @description Remove points from the shapes of a GTFS file in order to
#' reduce its size. It uses Douglas-Peucker algorithm internally.
#'
#' @param gtfs_data A list of data.tables read using gtfs2gps::read_gtfs().
#' @param tol Numerical tolerance value to be used by the Douglas-Peucker algorithm.
#' The default value is 0, which means that no data will be lost.
#' 
#' @return A GTFS data whose shapes is a subset of the input data.
#' @keywords internal
#'
simplify_shapes <- function(gtfs_data, tol = 0){
  
  gtfs_sf <- shapes_as_sf(gtfs_data)
  gtfs_sf$ID <- 1:nrow(gtfs_sf)
  
  # geometry operations
  gtfs_st_simpl <- terra::vect(gtfs_sf)
  gtfs_st_simpl <- terra::simplifyGeom(x = gtfs_st_simpl, tolerance = tol)
  gtfs_st_simpl <- terra::geom(gtfs_st_simpl)
  gtfs_st_simpl <- data.table::as.data.table(gtfs_st_simpl)
  
  # organize ouput data.table
  gtfs_st_simpl[data.table::setDT(gtfs_sf)
                , on = c("geom" = "ID")
                ,shape_id := i.shape_id]
  data.table::setnames(gtfs_st_simpl
                       ,old = c("x","y")
                       ,new = c("shape_pt_lon","shape_pt_lat"))
  gtfs_st_simpl[,shape_pt_sequence := 1:.N,by = shape_id]
  
  gtfs_data$shapes <- gtfs_st_simpl[,.(shape_id,shape_pt_lon,shape_pt_lat,shape_pt_sequence)]
  
  return(gtfs_data)
}
