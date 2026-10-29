# UPDATE NEWSTOPTIMES DATA.FRAME
# one trip of a stop pattern, on plain vectors: trip_name is its trip_id (for messages),
# st_seq/st_dep/st_arr are its stop_times and tpl the columns of the pattern's shape
# template (see process_pattern() in gtfs2gps.R). Returns the template rows of the trip
# (src) and its dist, speed, timestamp (unclassed seconds, not yet wrapped at midnight)
# and cumtime, or NULL when the trip is skipped
update_dt <- function(trip_name, st_seq, st_dep, st_arr, tpl){
  # ignore trip_id if original departure_time values are missing
  if(sum(!is.na(st_dep)) < 2){
    cli::cli_inform( # nocov start
      "Trip {.val {trip_name}} has less than two stop_ids. Ignoring it.") # nocov end
    return(NULL) # nocov
  }

  # the trip's times by stop_sequence. Same result as an update-join on = "stop_sequence":
  # rows without a match keep the template's value, NA matches NA, and a duplicated
  # stop_sequence takes the trip's last row
  m <- length(st_seq) + 1L - match(tpl$stop_sequence, rev(st_seq))
  hit <- !is.na(m)
  dep <- tpl$departure_time
  arr <- tpl$arrival_time
  dep[hit] <- st_dep[m[hit]]
  arr[hit] <- st_arr[m[hit]]

  # each stop with a time gets an extra row just before it, at its arrival_time, which
  # keeps the original dist; the stop row itself gets dist 0. The template's id is its
  # row position, so rows are selected by position
  lim0 <- which(!is.na(dep) & tpl$has_stop)
  src <- sort(c(seq_along(dep), lim0))

  extra <- duplicated(src, fromLast = TRUE)
  dep <- dep[src]
  arr <- arr[src]
  dep[extra] <- arr[extra]
  dist <- tpl$dist[src]
  dist[duplicated(src)] <- 0

  last_point_was_stop <- FALSE

  # speed, cumtime and timestamp are computed on plain vectors: a data.table
  # sub-assignment per segment dominated gtfs2gps() run time. ts is unclassed so
  # that [.ITime and round.ITime (which rounds to hours) never dispatch.
  ts  <- as.integer(data.table::as.ITime(dep))
  cd  <- tpl$cumdist[src]
  # once per trip: diff() per segment (S3 dispatch) was the main cost of the loop
  dcd <- diff(cd)
  spd <- rep(NA_real_, length(src))
  spd[1] <- 1e-12
  ctm <- numeric(length(src))

  lim0 <- which(!is.na(ts) & tpl$has_stop[src])

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
    ctm[a:b] <- cumsum(c(ctm[a], dcd[a:(b - 1)] / v))

    spd[a] <- 1e-12

    ts[a:(b - 1)] <- as.integer(ts[a] + round(ctm[a:(b - 1)] - ctm[a]))
    last_point_was_stop <- FALSE
  }

  ctm[is.na(spd)] <- NA

  return(list(src = src, dist = dist, speed = spd, timestamp = ts, cumtime = ctm))
}
