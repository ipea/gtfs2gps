#' @title Convert GTFS to GPS-like data given a spatial resolution
#' 
#' @description Convert GTFS data to GPS format by sampling points using a given
#' spatial resolution. This function creates additional points in order to
#' guarantee that two points in a same trip will have at most a given
#' distance, indicated as a spatial resolution. It is possible to use future package
#' to parallelize the execution (or use argument plan). This function also
#' uses progressr internally to show progress bars. See the example below on how
#' to show a progress bar while executing this function.
#' 
#' @param gtfs_data A path to a GTFS file to be converted to GPS, or a GTFS data
#' represented as a list of data.tables.
#' @param spatial_resolution The spatial resolution in meters. Default is 100m.
#' This function only creates points in order to guarantee that the minimum
#' distance between two consecutive points will be at most the
#' spatial_resolution. If a given shape has two consecutive points with a
#' distance lower than the spatial resolution, the algorithm will not remove
#' such points. 
#' @param parallel Decides whether the function should run in parallel. Defaults is FALSE.
#' When TRUE, it will use all cores available minus one using future::plan() with
#' strategy "multisession" internally.
#' Note that it is possible to create your own plan before calling gtfs2gps().
#' In this case, do not use this argument.
#' @param ncores Number of cores to be used in parallel execution. When 
#'        `parallel = FALSE`, this argument is ignored. When `parallel = TRUE`,
#'        then by default the function uses all available cores minus one.
#' @param strategy This argument is deprecated. Please use argument plan instead or
#' use future::plan() directly.
#' @param filepath Output file path. As default, the output is returned when gtfs2gps finishes.
#' When this argument is set, each route is saved into a txt file within filepath,
#' with the name equals to its id. In this case, no output is returned. See argument
#' compress for another option.
#' @param compress Argument that can be used only with filepath. When TRUE, it
#' compresses the output files by saving them using rds format. Default value is FALSE.
#' Note that compress guarantees that the data saved will be read in the same way as it
#' was created in R. If not compress, the txt extension requires the data to be converted
#' from ITime to string, and therefore they need to manually converted back to ITime to 
#' be properly handled by gtfs2gps.
#' @param continue Argument that can be used only with filepath. When TRUE, it
#'        skips processing the shape identifiers that were already saved into 
#'        files. It is useful to continue processing a GTFS file that was stopped
#'        for some reason. Default value is FALSE.
#' @param snap_method The method used to snap stops to the route geometry. There
#'        are two available methods: `nearest1` and `nearest2`. Defaults to 
#'        `nearest2`. See details for more info.
#' @param quiet Hide messages while processing the data? Defaults to FALSE.
#' 
#' @details After creating geometry points for a given shape id, the `gtfs2gps()`
#' function snaps the stops to the route geometry. Two strategies are implemented
#' to do this. 
#' - The `nearest2` method (default) triangulates the distance between each stop 
#' and the two nearest points in the route geometry to decide which point the 
#' stop should be snapped to. If there is any stop that is further away to the 
#' route geometry  than `spatial_resolution`, the algorithm recursively doubles 
#' the `spatial_resolution` to do the search/snap of all stops.
#' - The `nearest1` method traverses the geometry points computing their 
#' distances to the first stop. Whenever it finds a distance to the stop smaller
#' than `spatial_resolution`, then the stop will be snapped to such point. The 
#' algorithm then applies the same strategy to the next stop until the vector of
#' stops end.
#' 
#' The `speed`, `cumdist`, and `cumtime` are based on the difference of distance 
#' and time between the current and previous row of the same trip. It means that 
#' the first data point at the first stop of each trip represens a stationary 
#' vehicle. The `adjust_speed()` function can be used to post-process the output 
#' to replace eventual `NA` values in the `speed` column.
#' 
#' Each stop is presented as two data points for each trip in the output. The 
#' `timestamp` value in the first data point represents the time when the 
#' vehicle arrived at that stop (corresponding the `arrival_time` column in the
#' `stop_times.txt` file), while the `timestamp` in the second data point 
#' represents the time when the vehicle departured from that stop (corresponding
#' the `departure_time` column in the `stop_times.txt` file). The second point 
#' considers that the vehicle is stationary at the stop, immediately before 
#' departing.
#' 
#' Some GTFS feeds do not report embark/disembark times (so `arrival_time` and 
#' `departure_time` are identical at the same stop). In this case, the user can
#' call the `adjust_arrival_departure()` function to set the minimum time each 
#' vehicle will spend at stops to embark/disembark passengers.
#' 
#' To avoid division by zero, the minimum speed of vehicles in the output is
#' 1e-12 Km/h, so that vehicles are never completely stopped.
#' 
#' @return A `data.table`, where each row represents a GPS point. The following 
#' columns are returned (units of measurement in parenthesis): dist and cumdist 
#' (meters), cumtime (seconds), shape_pt_lon and shape_pt_lat (degrees), speed 
#' (km/h), timestamp (hh:mm:ss).
#' 
#' @export
#' @examples
#' library(gtfs2gps)
#' 
#' gtfs <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps")) |>
#'   gtfstools::filter_by_shape_id("T2-1") |>
#'   filter_single_trip()
#'   
#' poa_gps <- progressr::with_progress(gtfs2gps(gtfs, quiet=TRUE))
#' 
gtfs2gps <- function(gtfs_data,
                     spatial_resolution = 100,
                     parallel = TRUE,
                     ncores = NULL,
                     strategy = NULL,
                     filepath = NULL,
                     compress = FALSE,
                     snap_method = "nearest2",
                     continue = FALSE,
                     quiet = FALSE){
  
  if(quiet) return(suppressMessages(gtfs2gps(gtfs_data, spatial_resolution, parallel, ncores, strategy, filepath, compress, snap_method, continue)))
  
  if(!is.null(strategy)){
    warning("Argument 'strategy' is deprecated and will be removed in a future version.") # nocov
  }
  
  ###### PART 1. Load and prepare data inputs ------------------------------------
  if(compress & is.null(filepath)){
    stop("Cannot use argument 'compress' without passing a 'filepath'.")
  }
  
  if(continue & is.null(filepath)){
    stop("Cannot use argument 'continue' without passing a 'filepath'.")
  }
  
  original_gtfs_data_arg <- deparse(substitute(gtfs_data))
  
  # Unzipping and reading GTFS.zip file
  if(is.character(gtfs_data)){
    message(paste("Unzipping and reading", basename(gtfs_data)))
    gtfs_data <- read_gtfs(gtfszip = gtfs_data)
  }
  
  # do not change input data by reference
  gtfs_data <- data.table::copy(gtfs_data)
  
  # if gtfs is frequency-based, then convert it to stop times
  if (test_gtfs_freq(gtfs_data) =='frequency') {
    gtfs_data <- gtfstools::frequencies_to_stop_times(gtfs_data)
  }  
  
  # convert departure and arrival times from strings to seconds
  gtfs_data$stop_times[, departure_time := string_to_seconds(departure_time)]
  gtfs_data$stop_times[, arrival_time := string_to_seconds(arrival_time)]
  
  # Convert all shapes into sf objects
  message("Converting shapes to sf objects")
  shapes_sf <- gtfs_shapes_as_sf(gtfs_data)
  
  ###### PART 2. Analysing data type ----------------------------------------------
  corefun <- function(shapeid){
    if(continue){
      extension <- ifelse(compress, ".rda", ".txt")
      file <- paste0(filepath, "/", shapeid, extension)
      if(file.exists(file)) return(NULL)
    }
    
    # test
    # all_shapeids <- unique(shapes_sf$shape_id)
    # shapeid <- all_shapeids[1]
    # message(shapeid)
    
    ## Select corresponding route, route type, stops and shape of that trip
    
    # identify route id
    routeid <- gtfs_data$trips[shape_id == shapeid]$route_id[1]
    
    # get all trips linked to that route
    all_tripids <- unique( gtfs_data$trips[shape_id == shapeid & route_id == routeid, ]$trip_id )
    
    # nstop = number of valid stops in each trip_id
    nstop <- gtfs_data$stop_times[trip_id %chin% all_tripids, .N, by = "trip_id"]$N
    
    # Get the stops sequence with lat long linked to that route
    # each shape_id only has one stop sequence
    
    if(length(nstop) == 0){
      message(paste0("Shape '", shapeid, "' has zero stops. Ignoring it.")) # nocov
      return(NULL) # nocov
    }
    
    # check stop sequence
    stops_seq <- gtfs_data$stop_times[trip_id == all_tripids[which.max(nstop)]
                                      , .(stop_id, stop_sequence,  arrival_time, departure_time)]
    stops_seq[gtfs_data$stops
              , on = "stop_id"
              , c('stop_lat', 'stop_lon') := list(i.stop_lat, i.stop_lon)] # add lat long info
    
    data.table::setorderv(stops_seq, "stop_sequence")
    
    # convert stops to sf
    stops_sf <- sfheaders::sf_point(stops_seq, x = "stop_lon", y = "stop_lat", keep = TRUE)
    sf::st_crs(stops_sf) <- sf::st_crs(shapes_sf)
    
    # new faster version using sfheaders
    new_shape <- subset(shapes_sf, shape_id == shapeid)
    new_shape <- sf::st_segmentize(x = new_shape
                                   ,dfMaxLength =  units::set_units(spatial_resolution / 1000, "km"))
    new_shape <- sfheaders::sf_cast(new_shape, "POINT")

    # snap stops the nodes of the shape route
    temp_stops_coords <- sf::st_coordinates(stops_sf)
    temp_shape_coords <- sf::st_coordinates(new_shape)
    
    mymethod <- cpp_snap_points_nearest2
    
    if(snap_method == "nearest1"){
      mymethod <- cpp_snap_points_nearest1
    }
    
    snapped <- mymethod(temp_stops_coords, 
                        temp_shape_coords,
                        units::set_units(spatial_resolution, "m"))
    
    # Skip shape_id IF there are no snapped stops
    if (is.null(snapped) | length(snapped) == 0 ) {
      message(paste0("Shape '", shapeid, "' has no snapped stops. Ignoring it."))  # nocov
      return(NULL) # nocov
    }
    
    # Skip shape_id IF there is no route_id associated with that shape_id
    if (is.na(routeid)) {
      message(paste0("Shape '", shapeid, "' has no route_id. Ignoring it."))  # nocov
      return(NULL) # nocov
    }
    
    # update stops_seq with snap stops to route shape
    stops_seq$ref <- snapped
    
    ### Start building new stop_times.txt file
    
    # get shape points in high resolution
    new_stoptimes <- data.table::data.table(shape_id = new_shape$shape_id[1],
                                            id = seq_len(nrow(new_shape)),
                                            shape_pt_lon = sf::st_coordinates(new_shape)[,1],
                                            shape_pt_lat = sf::st_coordinates(new_shape)[,2])
    
    # add route type
    if (!is.null(gtfs_data$routes)) {
      routetype <- gtfs_data$routes[route_id == routeid]$route_type
      new_stoptimes[, route_type := routetype ]
    }
    
    ## Add stops to new_stoptimes  
    new_stoptimes[stops_seq, on = c("id" = "ref"),
                  ":="(stop_id = i.stop_id
                       ,stop_sequence = i.stop_sequence
                       ,departure_time = i.departure_time
                       ,arrival_time = i.arrival_time)]
    #new_stoptimes[!is.na(stop_id),":="(
    #  shape_pt_lon = stop_lon
    #  ,shape_pt_lat = stop_lat
    #)]
    #new_stoptimes[,":="(stop_lon = NULL,stop_lat = NULL)]
    # calculate Distance between successive points
    new_stoptimes[, dist := rcpp_distance_haversine(shape_pt_lat
                                                    , shape_pt_lon
                                                    , data.table::shift(shape_pt_lat, type = "lead")
                                                    , data.table::shift(shape_pt_lon, type = "lead")
                                                    , tolerance = 1e10)]
    # new_stoptimes[, dist := rcpp_distance_haversine(shape_pt_lat, shape_pt_lon, data.table::shift(shape_pt_lat, type = "lag"), data.table::shift(shape_pt_lon, type = "lag"), tolerance = 1e10)]
    # new_stoptimes[1, dist := 0]
    new_stoptimes <- na.omit(new_stoptimes, cols = "dist")
    
    if (dim(new_stoptimes)[1] < 2) {
      message(paste0("Shape '", shapeid, "' has less than two stops after conversion. Ignoring it."))  # nocov
      return(NULL) # nocov
    }
    
    if (length(which(!is.na(new_stoptimes$stop_sequence))) < 2) {
      message(paste0("Shape '", shapeid, "' has less than two stop_sequences after conversion. Ignoring it."))  # nocov
      return(NULL) # nocov
    }
    
    ###### PART 2.2 Function recalculate new stop_times for each trip id of each Shape id ------------------------------
    new_stoptimes <- lapply(X = seq_along(all_tripids), FUN = update_freq,
                            new_stoptimes, gtfs_data, all_tripids)
    
    new_stoptimes <- data.table::rbindlist(new_stoptimes)
    
    if (is.null(new_stoptimes$departure_time)) {
      message(paste0("Shape '", shapeid, "' has no departure_time. Ignoring it."))  # nocov
      return(NULL)  # nocov
    }
    
    # new_stoptimes$lag <- NULL
    new_stoptimes$arrival_time <- NULL
    new_stoptimes$departure_time <- NULL
    
    data.table::setcolorder(new_stoptimes, c("shape_id","trip_id", "route_type"
                                             , "id", "timestamp", "shape_pt_lon", "shape_pt_lat"
                                             , "stop_id", "stop_sequence"
                                             , "speed", "dist", "cumdist" 
                                             , "cumtime"))
    
    #na_values <- length(which(is.na(new_stoptimes$speed)))
    #
    #if(na_values > 1){
    #  message(paste0(na_values, " 'speed' values are NA for shape_id '", shapeid, "'."))
    #}
    
    infinite_values <- length(which(is.infinite(new_stoptimes$speed)))
    
    if(infinite_values > 0){
      message(paste0(infinite_values, " 'speed' values are Inf for shapeid '", shapeid, "'."))
    }
    
    negative_values <- length(which(new_stoptimes$speed <= 0))
    
    if(negative_values > 0){
      message(paste0(negative_values, " 'speed' values are zero or negative for shapeid '", shapeid, "'."))
    }
    
    new_stoptimes[, speed := units::set_units(speed, "km/h") ]
    new_stoptimes[, dist := units::set_units(dist, "m") ]
    new_stoptimes[, cumdist := units::set_units(cumdist, "m") ]
    new_stoptimes[, cumtime := units::set_units(cumtime, "s") ]
    
    if(!is.null(filepath)){ # Write object
      if(compress)
        saveRDS(object = new_stoptimes,
                file = paste0(filepath, "/", shapeid, ".rds"), compress = TRUE)
      else
        data.table::fwrite(x = new_stoptimes,
                           file = paste0(filepath, "/", shapeid, ".txt"))
      return(NULL)
    }
    
    return(new_stoptimes)
  }
  
  ###### PART 3. Apply Core function in parallel to all shape ids------------------------------------
  
  if(parallel)
  {
    # number of cores
    if (is.null(ncores))
      ncores <- parallelly::availableCores(omit = 1)

    message(paste('Using', ncores, 'CPU cores'))
    
    oplan <- future::plan("multisession", workers = ncores)
    on.exit(future::plan(oplan), add = TRUE)
  }
  
  badShapes <- c()
  msgs <- c()
  all_shapeids <- unique(shapes_sf$shape_id)
  p <- progressr::progressor(steps = length(all_shapeids))
  
  tryCorefun <- function(shapeid){
    p()
    result <- NULL
    tryCatch({result <- corefun(shapeid)}, error = function(msg) {
      badShapes <<- c(badShapes, shapeid) # nocov
      msgs <<- c(msgs, msg)
    })
    
    return(result)
  }
  
  message("Processing the data")
  requiredPackages = c('data.table', 'sf', 'Rcpp', 'sfheaders', 'units')
  output <- furrr::future_map(.x = all_shapeids, .f = tryCorefun, 
                              .options = furrr::furrr_options(
                                packages = requiredPackages))
  output <- data.table::rbindlist(output)
  
  if(length(badShapes) > 0){
    if(original_gtfs_data_arg == ".") original_gtfs_data_arg <- "<your gtfs data>" # nocov
    
    
    message(paste0("Some internal bug occurred while processing gtfs data.\n", # nocov
                   "Please give us a feedback by creating a GitHub issue\n", # nocov
                   "(https://github.com/ipeaGIT/gtfs2gps/issues/new)\n"), # nocov
            "and attaching a subset of your data created from the\n", # nocov
            "code below:\n", # nocov
            "################################################") # nocov
    
    print(msgs)
    
    ids <- paste0("ids <- c('", paste(badShapes, collapse = "', '"), "')") # nocov
    code1 <- paste0("data <- gtfstools::filter_by_shape_id(", original_gtfs_data_arg, ", ids)") # nocov
    code2 <- "gtfs2gps::write_gtfs(data, 'shapes_with_error.zip')" # nocov
    
    message(paste(ids, code1, code2, sep = "\n")) # nocov
    message("################################################") # nocov
  }
  
  total_shapes <- data.table::uniqueN(gtfs_data$shapes$shape_id)
  processed_shapes <- data.table::uniqueN(output$shape_id)
  
  if(processed_shapes < total_shapes && is.null(filepath)){
    perc <- round(processed_shapes / total_shapes * 100, 2)
    message(paste0(processed_shapes, " out of ", total_shapes, " shapes (", perc, "%) were properly processed."))
  }
  
  total_trips <- data.table::uniqueN(gtfs_data$trips$trip_id)
  processed_trips <- data.table::uniqueN(output$trip_id)
  
  if(processed_trips < total_trips && is.null(filepath)){
    perc <- round(processed_trips / total_trips * 100, 2)
    message(paste0(processed_trips, " out of ", total_trips, " trips (", perc, "%) were properly processed."))
  }
  
  if(is.null(filepath)){
    if(sum(is.na(output$speed)) > 1)
      message("Some 'speed' values are NA in the returned data.")
    
    if(any(is.infinite(output$speed)))
      message("Some 'speed' values are Inf in the returned data.")
    
    # check if there are any trips with negative speed
    trips_negative_speed <- unique(output$trip_id[which(output$speed < units::set_units(0, "km/h"))])
    
    if(length(trips_negative_speed) > 0 ){
      message(paste0("There are negative speeds reported in the GTFS for the following trip_id's: ",  paste0(trips_negative_speed, collapse=", ")))}
    
    if(is.null(output) || dim(output)[1] == 0) return(NULL)
    
    return(output)
  }
  else
    return(NULL)
}
