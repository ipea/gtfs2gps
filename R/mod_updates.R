# UPDATE NEWSTOPTIMES DATA.FRAME
# one trip: tripid is its index in all_tripids, stoptimes_trip its rows of stop_times and
# new_stoptimes the shape template of its stop pattern, which is not modified
update_dt <- function(tripid, stoptimes_trip, new_stoptimes, all_tripids){
  # ignore trip_id if original departure_time values are missing
  if(sum(!is.na(stoptimes_trip$departure_time)) < 2){
    cli::cli_inform( # nocov start
      "Trip {.val {all_tripids[tripid]}} has less than two stop_ids. Ignoring it.") # nocov end
    return(NULL) # nocov
  }

  # the trip's times by stop_sequence, on plain vectors. Same result as an update-join
  # on = "stop_sequence": rows without a match keep the template's value, NA matches NA,
  # and a duplicated stop_sequence takes the trip's last row
  m <- nrow(stoptimes_trip) + 1L - match(new_stoptimes$stop_sequence
                                         , rev(stoptimes_trip$stop_sequence))
  hit <- !is.na(m)
  dep <- new_stoptimes$departure_time
  arr <- new_stoptimes$arrival_time
  dep[hit] <- stoptimes_trip$departure_time[m[hit]]
  arr[hit] <- stoptimes_trip$arrival_time[m[hit]]

  # each stop with a time gets an extra row just before it, at its arrival_time, which
  # keeps the original dist; the stop row itself gets dist 0. The template's id is its
  # row position, so rows are selected by position
  lim0 <- which(!is.na(dep) & !is.na(new_stoptimes$stop_id))
  src <- sort(c(seq_len(nrow(new_stoptimes)), lim0))
  new_stoptimes <- new_stoptimes[src]

  extra <- duplicated(src, fromLast = TRUE)
  dep <- dep[src]
  arr <- arr[src]
  dep[extra] <- arr[extra]
  dist <- new_stoptimes$dist
  dist[duplicated(src)] <- 0

  last_point_was_stop <- FALSE

  # speed, cumtime and timestamp are computed on plain vectors: a data.table
  # sub-assignment per segment dominated gtfs2gps() run time. ts is unclassed so
  # that [.ITime and round.ITime (which rounds to hours) never dispatch.
  ts  <- as.integer(data.table::as.ITime(dep))
  cd  <- new_stoptimes$cumdist
  spd <- rep(NA_real_, length(src))
  spd[1] <- 1e-12
  ctm <- numeric(length(src))

  lim0 <- which(!is.na(ts) & !is.na(new_stoptimes$stop_id))

  for(i in 1:(length(lim0) - 1)){
    a <- lim0[i]
    b <- lim0[i + 1]

    dt <- ts[b] - ts[a]
    if(dt < 0) dt <- dt + 86400 # one day in seconds

    if(a + 1 == b && !last_point_was_stop) {
      # two consecutive points with arrival_time don't need to be interpolated
      last_point_was_stop <- TRUE
      ctm[b] <- ctm[a] + dt
      spd[b] <- 1e-12
      next
    }

    # m/s; NaN when the pair has neither distance nor time, Inf when it has
    # distance but no time (identical stop times); never -Inf (cumdist is non-decreasing)
    v <- (cd[b] - cd[a]) / as.numeric(dt)

    spd[a:b] <- 3.6 * v # km/h

    # cumsum restarted from the stored cumtime[a] of each segment on purpose:
    # R accumulates cumsum in long double, so one cumsum over the whole trip
    # would differ in the last bits
    ctm[a:b] <- cumsum(c(ctm[a], diff(cd[a:b]) / v))

    spd[a] <- 1e-12

    ts[a:(b - 1)] <- as.integer(ts[a] + round(ctm[a:(b - 1)] - ctm[a]))
    last_point_was_stop <- FALSE
  }

  ctm[is.na(spd)] <- NA

  # structure() rather than as.ITime(): the latter wraps values >= 86400, which
  # interpolated rows past midnight legitimately carry (adjust_speed() unwraps)
  data.table::set(new_stoptimes
                  , j = c("departure_time", "arrival_time", "dist", "id", "trip_id"
                          , "speed", "timestamp", "cumtime", "trip_number")
                  , value = list(dep, arr, dist, seq_along(src), all_tripids[tripid]
                                 , spd, structure(ts, class = "ITime"), ctm, tripid))
  
  # Get lag
  #new_stoptimes[!is.na(departure_time) & !is.na(stop_id)
  #              ,lag := departure_time - arrival_time]
  #new_stoptimes[is.na(lag), lag := 0]
  # Speed info that was missing (either before or after 1st/last stops)
  # Get trip duration in seconds
  #  new_stoptimes[, cumtime := cumsum(3.6 * dist / speed)]
  
  # reorder columns
  data.table::setcolorder(new_stoptimes, c("trip_id", "route_type", "id", 
                                           "shape_pt_lon", "shape_pt_lat", 
                                           "departure_time", "stop_id", 
                                           "stop_sequence", "dist", "cumdist",
                                           "speed", "cumtime"))
  
  # distance from trip start to 1st stop
  #  dist_1st <- new_stoptimes[id == lim0[1]]$cumdist # in m
  
  # get the depart/arrival time from 1st stop
  #departtime_1st <- as.numeric(new_stoptimes[id == lim0[1]]$departure_time)
  #departtime_1st <- departtime_1st - (3.6 * dist_1st / new_stoptimes$speed[1]) # time in seconds
  #  arrival_1st <- as.numeric(new_stoptimes[id == lim0[1]]$arrival_time)
  #  arrival_1st <- arrival_1st - (3.6 * dist_1st / new_stoptimes$speed[1]) # time in seconds
  
  
  # Determine the start time of the trip (time stamp the 1st GPS point of the trip)
  #suppressWarnings(new_stoptimes[id == 1, departure_time := round(departtime_1st)])
  #  suppressWarnings(new_stoptimes[id == lim0[1], arrival_time := round(arrival_1st)]) 
  
  # recalculate time stamps, except the given 'departure_time's from stop sequences
  #stop_id_nok <- which(is.na(new_stoptimes$departure_time))
  # update indexes in 'newstoptimes'
  # new_stoptimes[, departure_time := departure_time[lim0[1]] +  cumtime + cumsum(lag)]
  #  new_stoptimes[, arrival_time := departure_time - lag]
  
  # round
  #  new_stoptimes[, timestamp := round(timestamp)]
  #  new_stoptimes[, arrival_time := round(arrival_time)]
  
  return(new_stoptimes)
}