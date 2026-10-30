
#' @title Remove invalid objects from GTFS data
#' 
#' @description Remove all objects from GTFS data that are not used in all relations
#' that they are required to be. That is,
#' agency-routes relation (agency_id), routes-trips relation (route_id), 
#' trips-shapes relation (shape_id), trips-frequencies relation (trip_id),
#' trips-stop_times relation (trip_id), stop_times-stops relation (stop_id),
#' and trips-calendar relation (service_id),
#' recursively, until GTFS data does not reduce its size anymore. For example,
#' if one agency_id belongs to routes but not to agency will be removed. This might
#' cause one cascade removal of objects in other relations that originally
#' did not have any inconsistency.
#' @param gtfs_data A list of data.tables read using gtfs2gps::read_gtfs().
#' @param only_essential Remove only the essential files? The essential files are all but 
#' agency, calendar, and routes. Default is TRUE, which means that agency-routes,
#' routes-trips, and trips-calendar relations
#' will not be processed as restrictions to remove objects.
#' @param prompt_invalid Show the invalid objects. Default is FALSE.
#' @return A subset of the input GTFS data. 
#' @export
#' @examples
#' poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"))
#' object.size(poa)
#' subset <- remove_invalid(poa)
#' object.size(subset)
remove_invalid <- function(gtfs_data, only_essential = TRUE, prompt_invalid = FALSE){
  newsize <- object.size(gtfs_data)
  size <- newsize + 1
  
  removed <- list(
    agency_ids = c(),
    route_ids = c(),
    shape_ids = c(),
    trip_ids = c(),
    stop_ids = c(),
    service_ids = c()
  )
  
  while(newsize < size){
    size <- newsize
    
    # agency-routes relation (agency_id)
    if(!only_essential && !is.null(gtfs_data$agency) && !is.null(gtfs_data$routes) &&
       (nrow(gtfs_data$agency) > 1 || !all(gtfs_data$routes$agency_id %in% c(NA, "")))){ # agency_id is optional in single-agency feeds
      agency_ids <- intersect(gtfs_data$agency$agency_id, gtfs_data$routes$agency_id)
      removed$agency_ids <- c(removed$agency_ids, setdiff(gtfs_data$agency$agency_id, gtfs_data$routes$agency_id))

      gtfs_data$agency <- subset(gtfs_data$agency, agency_id %in% agency_ids)
      gtfs_data$routes <- subset(gtfs_data$routes, agency_id %in% agency_ids)
    }
  
    # routes-trips relation (route_id)
    if(!only_essential && !is.null(gtfs_data$routes)){
      route_ids <- intersect(gtfs_data$routes$route_id, gtfs_data$trips$route_id)
      removed$route_ids <- c(removed$route_ids, setdiff(gtfs_data$routes$route_id, gtfs_data$trips$route_id))
  
      gtfs_data$routes <- subset(gtfs_data$routes, route_id %in% route_ids)
      gtfs_data$trips  <- subset(gtfs_data$trips,  route_id %in% route_ids)
    }

    # trips-shapes relation (shape_id)
    shape_ids <- intersect(gtfs_data$trips$shape_id, gtfs_data$shapes$shape_id)
    removed$shape_ids <- c(removed$shape_ids, setdiff(gtfs_data$trips$shape_id, gtfs_data$shapes$shape_id))

    gtfs_data$trips  <- subset(gtfs_data$trips,  shape_id %in% shape_ids)
    gtfs_data$shapes <- subset(gtfs_data$shapes, shape_id %in% shape_ids)
    
    # trips-frequencies relation (trip_id)
    if(!is.null(gtfs_data$frequencies)){
      gtfs_data$frequencies <- subset(gtfs_data$frequencies, trip_id %chin% gtfs_data$trips$trip_id)
    }
    
    # trips-stop_times relation (trip_id)
    trip_ids <- intersect(gtfs_data$trips$trip_id, gtfs_data$stop_times$trip_id)
    removed$trip_ids <- c(removed$trip_ids, setdiff(gtfs_data$trips$trip_id, gtfs_data$stop_times$trip_id))

    gtfs_data$trips      <- subset(gtfs_data$trips,      trip_id %chin% trip_ids)
    gtfs_data$stop_times <- subset(gtfs_data$stop_times, trip_id %chin% trip_ids)
    
    # stop_times-stops relation (stop_id)
    stop_ids <- intersect(gtfs_data$stop_times$stop_id, gtfs_data$stops$stop_id)
    removed$stop_ids <- c(removed$stop_ids, setdiff(gtfs_data$stop_times$stop_id, gtfs_data$stops$stop_id))

    gtfs_data$stop_times <- subset(gtfs_data$stop_times, stop_id %chin% stop_ids)
    gtfs_data$stops      <- subset(gtfs_data$stops,      stop_id %chin% stop_ids)
  
    # trips-calendar relation (service_id)
    if(!only_essential & !is.null(gtfs_data$calendar)){
      service_ids <- intersect(gtfs_data$trips$service_id, c(gtfs_data$calendar$service_id, gtfs_data$calendar_dates$service_id))
      removed$service_ids <- c(removed$service_ids, setdiff(gtfs_data$trips$service_id, c(gtfs_data$calendar$service_id, gtfs_data$calendar_dates$service_id)))

      gtfs_data$trips    <- subset(gtfs_data$trips,    service_id %chin% service_ids)
      gtfs_data$calendar <- subset(gtfs_data$calendar, service_id %chin% service_ids)
    }

    # trips-calendar_dates relation (service_id)
    if(!only_essential & !is.null(gtfs_data$calendar_dates)){
      service_ids <- intersect(gtfs_data$trips$service_id, c(gtfs_data$calendar$service_id, gtfs_data$calendar_dates$service_id))
      removed$service_ids <- c(removed$service_ids, setdiff(gtfs_data$trips$service_id, c(gtfs_data$calendar$service_id, gtfs_data$calendar_dates$service_id)))
      
      gtfs_data$trips          <- subset(gtfs_data$trips,          service_id %chin% service_ids)
      gtfs_data$calendar_dates <- subset(gtfs_data$calendar_dates, service_id %chin% service_ids)
    }

    newsize <- object.size(gtfs_data)
  }

  if(prompt_invalid){
    for(element in names(removed)){
      len <- length(removed[[element]])
      
      if(len > 0)
        cli::cli_inform("{len} {element} removed: {.val {cli::cli_vec(removed[[element]], list('vec-trunc' = Inf))}}")
    }
  }
  
  return(gtfs_data)
}

#' @title Filter GTFS data using valid stop times
#'
#' @description Filter a GTFS data read using gtfs2gps::read_gtfs(). It removes
#' stop_times whose arrival_time or departure_time is missing or is not a
#' well-formed "H:MM:SS" time string (hours may exceed 24). It also filters stops and routes accordingly.
#' The input data is not modified.
#' @param gtfs_data A list of data.tables read using gtfs2gps::read_gtfs().
#' @return A filtered GTFS data.
#' @export
#' @examples
#' poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"))
#'
#' subset <- filter_valid_stop_times(poa)
filter_valid_stop_times <- function(gtfs_data){
  gtfs_data <- data.table::copy(gtfs_data)

  # keep only well-formed "H:MM:SS" times, ignoring surrounding whitespace (NA,
  # "" and malformed strings are dropped; grepl() returns FALSE for NA)
  gtfs_data$stop_times <- gtfs_data$stop_times[grepl(valid_gtfs_time, trimws(arrival_time)) &
                                                 grepl(valid_gtfs_time, trimws(departure_time))]

  stop_ids <- unique(gtfs_data$stop_times$stop_id)
  gtfs_data$stops <- subset(gtfs_data$stops, stop_id %in% stop_ids)

  if(!is.null(gtfs_data$routes)){
    route_ids <- unique(gtfs_data$trips$route_id)
    gtfs_data$routes <- subset(gtfs_data$routes, route_id %in% route_ids)
  }

  return(gtfs_data)
}

#' @title Filter GTFS trips in order to have one trip per shape_id
#' 
#' @description Filter a GTFS data by keeping only one trip per shape_id.
#' It also removes the unnecessary routes and stop_times accordingly.
#' @param gtfs_data A list of data.tables read using gtfs2gps::read_gtfs().
#' @return A filtered GTFS data. 
#' @export
#' @examples
#' poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"))
#' 
#' subset <- filter_single_trip(poa)
filter_single_trip <- function(gtfs_data){
  # one trip per shape; trips without a shape can't be converted
  gtfs_data$trips <- gtfs_data$trips[!is.na(gtfs_data$trips$shape_id) & !duplicated(gtfs_data$trips$shape_id), ]


  # unique trips
  trip_ids <- unique(gtfs_data$trips$trip_id)

  # filter stop_times
  gtfs_data$stop_times <- subset(gtfs_data$stop_times, trip_id %chin% trip_ids)
  
  # filter frequencies
  if(!is.null(gtfs_data$frequencies)){
    gtfs_data$frequencies <- subset(gtfs_data$frequencies, trip_id %chin% trip_ids)
  }
  
  # filter routes
  if(!is.null(gtfs_data$routes)){
    route_ids <- unique(gtfs_data$trips$route_id)
    gtfs_data$routes <- subset(gtfs_data$routes, route_id %in% route_ids)
  }

  return(gtfs_data)
}
