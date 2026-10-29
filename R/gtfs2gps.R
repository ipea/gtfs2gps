#' Convert one shape and all its trips to GPS points
#'
#' Called inside the furrr workers of \code{gtfs2gps()}. It is a package-level
#' function so that nothing from the \code{gtfs2gps()} frame is serialised with
#' it: \code{slice} holds only this shape's trips, stop_times, stops and geometry
#' (see the slicing block in \code{gtfs2gps()}). Errors are returned as condition
#' objects, which \code{gtfs2gps()} reports; \code{<<-} cannot cross a worker
#' boundary.
#' @noRd
convert_shape <- function(slice, routes, spatial_resolution, snap_method, filepath,
                          compress, continue, p){
  p()
  result <- tryCatch(shape_to_gps(slice, routes, spatial_resolution, snap_method, filepath,
                                  compress, continue),
                     error = function(e) e)
  return(result)
}

#' The former corefun() of gtfs2gps(): one shape, all its trips, one data.table
#' (or NULL when the shape is skipped, with a message saying why)
#' @noRd
shape_to_gps <- function(slice, routes, spatial_resolution, snap_method, filepath,
                         compress, continue){
  shapeid <- slice$shape_id
  if(continue){
    extension <- ifelse(compress, ".rds", ".txt")
    file <- paste0(filepath, "/", shapeid, extension)
    if(file.exists(file)) return(NULL)
  }
  
  
  ## Select corresponding route, route type, stops and shape of that trip
  
  if (NROW(slice$trips) == 0) {
    cli::cli_inform("Shape {.val {shapeid}} is not used by any trip. Ignoring it.") # nocov
    return(NULL) # nocov
  }

  # all trips that use this shape, whatever their route_id (routes may share a shape);
  # trips without a route_id are skipped
  trips_shape <- slice$trips[!is.na(route_id)]
  all_tripids <- unique(trips_shape$trip_id)

  if (length(all_tripids) == 0) {
    cli::cli_inform("Shape {.val {shapeid}} has no route_id. Ignoring it.")  # nocov
    return(NULL) # nocov
  }

  # group trips by stop pattern: stops are snapped once per pattern and cpp_expand_pattern()
  # joins each trip's times by stop_sequence, which is only valid within a pattern
  st_shape <- slice$stop_times[trip_id %chin% all_tripids, .(trip_id, stop_sequence, stop_id)]

  if(nrow(st_shape) == 0){
    cli::cli_inform("Shape {.val {shapeid}} has zero stops. Ignoring it.") # nocov
    return(NULL) # nocov
  }

  data.table::setorderv(st_shape, c("trip_id", "stop_sequence"))
  patterns <- st_shape[, .(pattern = paste(stop_sequence, stop_id, sep = ":", collapse = "|"))
                       , by = trip_id]
  pattern_trips <- split(patterns$trip_id, factor(patterns$pattern, levels = unique(patterns$pattern)))

  # the shape in high resolution: gtfs2gps() segmentizes all shapes in one call, and
  # only when that fails is each shape segmentized here
  if(is.null(slice$points)){
    new_shape <- sf::st_segmentize(x = slice$shape
                                   ,dfMaxLength =  units::set_units(spatial_resolution / 1000, "km"))
    new_shape <- sfheaders::sf_cast(new_shape, "POINT")
    slice$points <- list(shape_id = new_shape$shape_id[1], coords = sf::st_coordinates(new_shape))
  }
  temp_shape_coords <- slice$points$coords

  mymethod <- cpp_snap_points_nearest2

  if(snap_method == "nearest1"){
    mymethod <- cpp_snap_points_nearest1
  }

  process_pattern <- function(tripids){
    # stop sequence of this pattern
    stops_seq <- slice$stop_times[trip_id == tripids[1]
                                      , .(stop_id, stop_sequence,  arrival_time, departure_time)]
    stops_seq[slice$stops
              , on = "stop_id"
              , c('stop_lat', 'stop_lon') := list(i.stop_lat, i.stop_lon)] # add lat long info

    data.table::setorderv(stops_seq, "stop_sequence")

    # snap stops the nodes of the shape route (the same doubles as the coordinates of
    # the stops as sf points)
    temp_stops_coords <- cbind(as.double(stops_seq$stop_lon), as.double(stops_seq$stop_lat))

    # whole metres, truncated, as the C++ function takes an int (a units value in
    # another unit is converted first)
    snapped <- mymethod(temp_stops_coords,
                        temp_shape_coords,
                        as.integer(units::drop_units(units::set_units(spatial_resolution, "m"))))

    # Skip pattern IF there are no snapped stops
    if (is.null(snapped) | length(snapped) == 0 ) {
      cli::cli_inform("Shape {.val {shapeid}}: {length(tripids)} trip{?s} with a stop pattern that has no snapped stops. Ignoring {?it/them}.")  # nocov
      return(NULL) # nocov
    }

    # update stops_seq with snap stops to route shape
    stops_seq$ref <- snapped

    ### Start building new stop_times.txt file

    # get shape points in high resolution
    new_stoptimes <- data.table::data.table(shape_id = slice$points$shape_id,
                                            id = seq_len(nrow(temp_shape_coords)),
                                            shape_pt_lon = temp_shape_coords[,1],
                                            shape_pt_lat = temp_shape_coords[,2])

    # route type is filled per trip after all patterns are processed
    new_stoptimes[, route_type := routes$route_type[NA_integer_]]

    ## Add stops to new_stoptimes
    new_stoptimes[stops_seq, on = c("id" = "ref"),
                  ":="(stop_id = i.stop_id
                       ,stop_sequence = i.stop_sequence
                       ,departure_time = i.departure_time
                       ,arrival_time = i.arrival_time)]

    # calculate Distance between successive points
    new_stoptimes[, dist := rcpp_distance_haversine(shape_pt_lat
                                                    , shape_pt_lon
                                                    , data.table::shift(shape_pt_lat, type = "lead")
                                                    , data.table::shift(shape_pt_lon, type = "lead")
                                                    , tolerance = 1e10)]
    new_stoptimes <- na.omit(new_stoptimes, cols = "dist")

    if (dim(new_stoptimes)[1] < 2) {
      cli::cli_inform("Shape {.val {shapeid}}: {length(tripids)} trip{?s} with less than two points after conversion. Ignoring {?it/them}.")  # nocov
      return(NULL) # nocov
    }

    if (length(which(!is.na(new_stoptimes$stop_sequence))) < 2) {
      cli::cli_inform("Shape {.val {shapeid}}: {length(tripids)} trip{?s} with less than two stops after conversion. Ignoring {?it/them}.")  # nocov
      return(NULL) # nocov
    }

    ###### PART 2.2 recalculate new stop_times for each trip of this pattern ------------------------------
    # cumulative distance is the same for every trip of the pattern
    new_stoptimes[, cumdist := cumsum(dist)]

    # stop_times of each trip, split once per pattern instead of looked up per trip.
    # Grouped by position: an NA trip_id gets no rows, as `trip_id == NA` did, and a
    # trip named "NA" is not confused with it. split() keeps the row order within a
    # trip, on which cpp_expand_pattern() relies when a stop_sequence is duplicated.
    st <- slice$stop_times[trip_id %chin% tripids
                           , .(trip_id, stop_sequence, departure_time, arrival_time)]
    st_rows <- split(seq_len(nrow(st))
                     , factor(match(st$trip_id, tripids, incomparables = NA)
                              , levels = seq_along(tripids)))
    rows <- unlist(st_rows, use.names = FALSE)

    # all trips of the pattern at once, in C++ (src/expand_pattern.cpp)
    res <- cpp_expand_pattern(as.double(new_stoptimes$stop_sequence)
                              , as.integer(new_stoptimes$departure_time)
                              , as.integer(new_stoptimes$arrival_time)
                              , !is.na(new_stoptimes$stop_id)
                              , new_stoptimes$dist
                              , new_stoptimes$cumdist
                              , lengths(st_rows, use.names = FALSE)
                              , as.double(st$stop_sequence[rows])
                              , as.integer(st$departure_time[rows])
                              , as.integer(st$arrival_time[rows])
                              , capabilities("long.double"))

    # as in the former R code, the trips skipped before a failing trip are reported
    # first; the failure is caught by convert_shape() and reported for the shape
    for(k in which(res$status == 1L)){
      cli::cli_inform( # nocov start
        "Trip {.val {tripids[k]}} has less than two stop_ids. Ignoring it.") # nocov end
    }
    if(any(res$status == 2L)){
      cli::cli_abort("Trip {.val {tripids[res$status == 2L]}} has fewer than two timed stops on its shape." # nocov
                     , class = "gtfs2gps_trip_error") # nocov
    }

    converted <- res$status == 0L
    if(!any(converted)) return(NULL)
    n_rows <- res$n_rows[converted]

    # departure_time and arrival_time keep the template's values: they are dropped
    # from the output in shape_to_gps()
    new_stoptimes <- new_stoptimes[res$src]
    # match() keeps trip_number as the trip's index among all trips of the shape;
    # timestamps wrap at midnight (elapsed time is in cumtime)
    data.table::set(new_stoptimes
                    , j = c("dist", "id", "trip_id", "speed", "timestamp", "cumtime", "trip_number")
                    , value = list(res$dist, sequence(n_rows), rep(tripids[converted], n_rows)
                                   , res$speed
                                   , structure(res$timestamp %% 86400L, class = "ITime")
                                   , res$cumtime
                                   , rep(match(tripids[converted], all_tripids), n_rows)))

    return(new_stoptimes)
  }

  new_stoptimes <- data.table::rbindlist(lapply(pattern_trips, process_pattern))

  if (nrow(new_stoptimes) == 0) {
    cli::cli_inform("Shape {.val {shapeid}}: no trip could be converted. Ignoring it.") # nocov
    return(NULL) # nocov
  }

  data.table::setorderv(new_stoptimes, c("trip_number", "id"))

  if (is.null(new_stoptimes$departure_time)) {
    cli::cli_inform("Shape {.val {shapeid}} has no departure_time. Ignoring it.")  # nocov
    return(NULL)  # nocov
  }
  
  # by reference: `$<- NULL` copied the whole table twice
  data.table::set(new_stoptimes, j = c("arrival_time", "departure_time"), value = NULL)
  
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
    cli::cli_inform("{infinite_values} {.field speed} value{?s} {?is/are} Inf for shape {.val {shapeid}}.")
  }
  
  negative_values <- length(which(new_stoptimes$speed <= 0))
  
  if(negative_values > 0){
    cli::cli_inform("{negative_values} {.field speed} value{?s} {?is/are} zero or negative for shape {.val {shapeid}}.")
  }
  
  # route_type and units are set by gtfs2gps() on the whole output, and here only
  # for the shape's file
  if(!is.null(filepath)){ # Write object
    set_route_type(new_stoptimes, routes, trips_shape)
    set_gps_units(new_stoptimes)
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

#' route_type of each trip, by shape: a trip listed under two shapes takes the route of
#' each; for a trip listed twice in a shape, the last row wins (update join)
#' @noRd
set_route_type <- function(gps, routes, trips){
  if (!is.null(routes)) {
    trip_rt <- unique(routes[, .(route_id, route_type)], by = "route_id")[
      trips[!is.na(route_id), .(shape_id, trip_id, route_id)], on = "route_id"]
    gps[trip_rt, on = c("shape_id", "trip_id"), route_type := i.route_type]
  }
  return(invisible(gps))
}

#' units of the GPS columns, set by reference
#' @noRd
set_gps_units <- function(gps){
  gps[, speed := units::set_units(speed, "km/h") ]
  gps[, dist := units::set_units(dist, "m") ]
  gps[, cumdist := units::set_units(cumdist, "m") ]
  gps[, cumtime := units::set_units(cumtime, "s") ]
  return(invisible(gps))
}

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
#' Stops without times are placed along the shape at constant speed between the
#' timed stops. \code{\link[gtfstools]{fix_gtfs}} can clean a feed before
#' converting it (e.g. duplicated rows and unused ids), but the stop times it
#' interpolates may give spiky or infinite speeds here.
#'
#' @param gtfs_data A path to a GTFS file to be converted to GPS, or a GTFS data
#' represented as a list of data.tables.
#' @param spatial_resolution The spatial resolution in meters. Default is 100m.
#' This function only creates points in order to guarantee that the minimum
#' distance between two consecutive points will be at most the
#' spatial_resolution. If a given shape has two consecutive points with a
#' distance lower than the spatial resolution, the algorithm will not remove
#' such points. 
#' @param parallel Decides whether the function should run in parallel. Defaults to FALSE.
#' When TRUE, it will use all cores available minus one using future::plan() with
#' strategy "multisession" internally. Starting the R sessions and sending the
#' results back usually takes longer than the conversion itself, so this is
#' rarely faster than running sequentially.
#' Note that it is possible to create your own plan before calling gtfs2gps(),
#' which is then used even with parallel = FALSE.
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
                     parallel = FALSE,
                     ncores = NULL,
                     strategy = NULL,
                     filepath = NULL,
                     compress = FALSE,
                     snap_method = "nearest2",
                     continue = FALSE,
                     quiet = FALSE){
  
  if(quiet) return(suppressMessages(gtfs2gps(gtfs_data, spatial_resolution, parallel, ncores, strategy, filepath, compress, snap_method, continue)))
  
  if(!is.null(strategy)){
    cli::cli_warn(c("Argument {.arg strategy} is deprecated and will be removed in a future version.",
                    "i" = "Set the parallel backend with {.fn future::plan} instead."),
                  class = "deprecated_strategy")
  }

  ###### PART 1. Load and prepare data inputs ------------------------------------
  if(compress & is.null(filepath)){
    cli::cli_abort("Cannot use argument {.arg compress} without passing a {.arg filepath}.",
                   class = "gtfs2gps_filepath_error")
  }

  if(continue & is.null(filepath)){
    cli::cli_abort("Cannot use argument {.arg continue} without passing a {.arg filepath}.",
                   class = "gtfs2gps_filepath_error")
  }

  if(!is.null(filepath)) checkmate::assert_directory_exists(filepath, access = "w")
  checkmate::assert_choice(snap_method, c("nearest1", "nearest2"))
  
  original_gtfs_data_arg <- paste(deparse(substitute(gtfs_data)), collapse = " ")
  
  # Unzipping and reading GTFS.zip file
  if(is.character(gtfs_data)){
    cli::cli_inform("Unzipping and reading {.file {basename(gtfs_data)}}")
    gtfs_data <- read_gtfs(gtfszip = gtfs_data)
  }
  
  # do not change input data by reference
  gtfs_data <- data.table::copy(gtfs_data)
  
  # if gtfs is frequency-based, then convert it to stop times
  if (test_gtfs_freq(gtfs_data) =='frequency') {
    gtfs_data <- gtfstools::frequencies_to_stop_times(gtfs_data)
  }  
  
  # convert departure and arrival times from strings to seconds
  gtfs_data <- stop_times_to_seconds(gtfs_data)
  
  # Convert all shapes into sf objects
  cli::cli_inform("Converting shapes to sf objects")
  shapes_sf <- gtfs_shapes_as_sf(gtfs_data)
  
  ###### PART 2. Slice the feed per shape ----------------------------------------
  # Each worker receives only the trips, stop_times, stops and geometry of the
  # shapes it converts (passed as the mapped argument), instead of a closure that
  # would carry the whole feed to every worker. shape_id is character
  # (gtfs_shapes_as_sf() requires it), so the split groups are indexed by name.
  all_shapeids <- unique(shapes_sf$shape_id)
  # trips with NA route_id are kept: the guards in shape_to_gps() handle them as before
  trips <- gtfs_data$trips[shape_id %chin% all_shapeids]
  shape_of_row <- trips$shape_id[match(gtfs_data$stop_times$trip_id, trips$trip_id)]
  # split() drops the rows of other trips (NA) and keeps the row order within each shape
  st_by_shape <- split(gtfs_data$stop_times, f = shape_of_row)
  trips_by_shape <- split(trips, by = "shape_id")
  stop_shape <- data.table::data.table(shape_id = shape_of_row
                                       , stop_id = gtfs_data$stop_times$stop_id)
  stop_shape <- unique(stop_shape)[!is.na(shape_id)]
  stops_by_shape <- split(stop_shape[gtfs_data$stops, on = "stop_id", nomatch = NULL]
                          , by = "shape_id")
  # all shapes in high resolution in one call, much faster than one call per shape;
  # if it fails, shape_to_gps() segmentizes each shape, so that an error fails only
  # that shape. Shapes without trips (or already saved, with continue) are segmentized
  # too, so a geometry that only warns now warns here. lwgeom attaches sf (now also
  # with parallel = TRUE), whose startup message furrr used to hide when the shapes
  # were segmentized in its futures
  points <- tryCatch({
    pts <- suppressPackageStartupMessages(
      sf::st_segmentize(x = shapes_sf
                        , dfMaxLength = units::set_units(spatial_resolution / 1000, "km")))
    pts <- sfheaders::sf_cast(pts, "POINT")
    list(shape_id = pts$shape_id, coords = sf::st_coordinates(pts))
  }, error = function(e) NULL)
  shape_by_shape <- point_rows <- NULL
  if(is.null(points)){
    shape_by_shape <- split(shapes_sf, shapes_sf$shape_id)
  } else {
    point_rows <- split(seq_len(nrow(points$coords)), points$shape_id)
  }

  # a shape missing from a split gets a typed empty table, so that the guards in
  # shape_to_gps() report it exactly as before
  # groups are looked up by position: `[[id]]` never matches the name ""
  pick <- function(groups, id, template){
    i <- match(id, names(groups))
    if(is.na(i)) return(template[0])
    return(groups[[i]])
  }
  # each slice carries its points or, when segmentizing all shapes failed, its shape
  slices <- lapply(all_shapeids, function(id){
    slice <- list(shape_id = id
                  , trips = pick(trips_by_shape, id, gtfs_data$trips)
                  , stop_times = pick(st_by_shape, id, gtfs_data$stop_times)
                  , stops = pick(stops_by_shape, id, gtfs_data$stops))
    if(is.null(points)){
      slice$shape <- shape_by_shape[[match(id, names(shape_by_shape))]]
    } else {
      i <- match(id, names(point_rows))
      r <- if(is.na(i)) integer(0) else point_rows[[i]]
      slice$points <- list(shape_id = points$shape_id[r[1]]
                           , coords = points$coords[r, , drop = FALSE])
    }
    return(slice)
  })
  rm(trips, shape_of_row, st_by_shape, trips_by_shape, stop_shape, stops_by_shape, points
     , point_rows, shape_by_shape)
  # our own copy, and nothing below reads it: the slices hold what the workers need
  gtfs_data$stop_times <- NULL

  ###### PART 3. Apply Core function in parallel to all shape ids------------------------------------

  if(parallel)
  {
    # number of cores
    if (is.null(ncores))
      ncores <- parallelly::availableCores(omit = 1)

    cli::cli_inform("Using {ncores} CPU core{?s}")
    
    oplan <- future::plan("multisession", workers = ncores)
    on.exit(future::plan(oplan), add = TRUE)
  }
  
  p <- progressr::progressor(steps = length(all_shapeids))

  cli::cli_inform("Processing the data")
  requiredPackages = c('data.table', 'sf', 'sfheaders', 'units')
  # convert_shape() is a package-level function and every other argument is small,
  # so each worker is sent only its chunk of `slices`
  output <- furrr::future_map(.x = slices, .f = convert_shape
                              , routes = gtfs_data$routes
                              , spatial_resolution = spatial_resolution
                              , snap_method = snap_method
                              , filepath = filepath
                              , compress = compress
                              , continue = continue
                              , p = p
                              , .options = furrr::furrr_options(
                                packages = requiredPackages))

  # errors inside a worker come back as condition objects
  failed <- vapply(output, inherits, logical(1), what = "error")
  badShapes <- all_shapeids[failed]
  msgs <- output[failed]
  output <- data.table::rbindlist(output[!failed])
  
  if(length(badShapes) > 0){
    # "gtfs_data" is what the quiet = TRUE recursion sees instead of the user's name
    if(original_gtfs_data_arg %in% c(".", "gtfs_data")) original_gtfs_data_arg <- "<your gtfs data>"

    # ids and error texts are interpolated by index, never parsed as cli markup
    errs <- vapply(msgs, conditionMessage, character(1))
    shape_bullets <- paste0("{.val {badShapes[", seq_along(badShapes), "]}}: {errs[", seq_along(badShapes), "]}")
    names(shape_bullets) <- rep("x", length(badShapes))
    code <- c(paste0("ids <- ", paste(deparse(badShapes), collapse = "")),
              paste0("data <- gtfstools::filter_by_shape_id(", original_gtfs_data_arg, ", ids)"),
              "gtfs2gps::write_gtfs(data, 'shapes_with_error.zip')")

    cli::cli_warn(c("Some internal bug occurred while converting {length(badShapes)} shape{?s}.",
                    shape_bullets,
                    "i" = paste("Please open an issue at {.url https://github.com/ipea/gtfs2gps/issues/new}",
                                "and attach a subset of your data created with:"),
                    " " = "{.code {code[1]}}",
                    " " = "{.code {code[2]}}",
                    " " = "{.code {code[3]}}"),
                  class = "gtfs2gps_shape_error")
  }
  
  total_shapes <- data.table::uniqueN(gtfs_data$shapes$shape_id)
  processed_shapes <- data.table::uniqueN(output$shape_id)
  
  if(processed_shapes < total_shapes && is.null(filepath)){
    perc <- round(processed_shapes / total_shapes * 100, 2)
    cli::cli_inform("{processed_shapes} out of {total_shapes} shapes ({perc}%) were properly processed.")
  }
  
  total_trips <- data.table::uniqueN(gtfs_data$trips$trip_id)
  processed_trips <- data.table::uniqueN(output$trip_id)
  
  if(processed_trips < total_trips && is.null(filepath)){
    perc <- round(processed_trips / total_trips * 100, 2)
    cli::cli_inform("{processed_trips} out of {total_trips} trips ({perc}%) were properly processed.")
  }
  
  if(is.null(filepath)){
    # no shape converted: there is nothing to check
    if(is.null(output) || dim(output)[1] == 0) return(NULL)

    set_route_type(output, gtfs_data$routes, gtfs_data$trips)
    set_gps_units(output)

    if(sum(is.na(output$speed)) > 1)
      cli::cli_inform("Some {.field speed} values are NA in the returned data.")

    if(any(is.infinite(output$speed)))
      cli::cli_inform("Some {.field speed} values are Inf in the returned data.")

    # check if there are any trips with negative speed
    trips_negative_speed <- unique(output$trip_id[which(output$speed < units::set_units(0, "km/h"))])

    if(length(trips_negative_speed) > 0 ){
      cli::cli_inform("There are negative speeds reported in the GTFS for the following {.field trip_id}s: {.val {cli::cli_vec(trips_negative_speed, list('vec-trunc' = Inf))}}")}

    return(output)
  }
  else
    return(NULL)
}
