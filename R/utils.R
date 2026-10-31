# An H:MM:SS GTFS time (hours may exceed 24; minutes and seconds below 60, as in
# gtfstools::convert_time_to_seconds()). Used by filter_valid_stop_times().
valid_gtfs_time <- "^[0-9]+:[0-5][0-9]:[0-5][0-9]$"

#' Convert stop_times time strings to seconds after midnight
#'
#' Replaces the \code{arrival_time} and \code{departure_time} columns of
#' \code{gtfs$stop_times} with integer seconds after midnight, using
#' \code{gtfstools::convert_time_to_seconds()}, which turns malformed strings
#' into \code{NA} with a warning of class \code{gtfstools_malformed_time}.
#' The conversion is done in place, so callers must copy first.
#'
#' @param gtfs A GTFS object (a list of data.tables). Plain lists are promoted
#'   with \code{gtfstools::as_dt_gtfs()}, which copies every table.
#'
#' @return The GTFS object, with integer time columns in \code{stop_times}.
#'
#' @noRd
stop_times_to_seconds <- function(gtfs) {
  gtfs <- gtfstools::convert_time_to_seconds(
    gtfstools::as_dt_gtfs(gtfs),
    file = "stop_times",
    by_reference = TRUE
  )

  gtfs$stop_times[, `:=`(
    departure_time = departure_time_secs,
    arrival_time = arrival_time_secs,
    departure_time_secs = NULL,
    arrival_time_secs = NULL
  )]

  return(gtfs)
}


#' Convert the shapes of a slice of the feed, and all their trips, to GPS points
#'
#' A slice holds the shapes to convert (\code{shape_ids}, in output order), their
#' trips, the stop_times rows they own (\code{owner}: the first shape listing the
#' row's trip in \code{trips}, decided once for the whole feed), the stops, and the
#' shapes in high resolution (\code{points}), or their geometry (\code{shapes}) when
#' segmentizing all shapes at once failed. \code{gtfs2gps()} passes one slice with
#' the whole feed, or one slice per shape (with \code{filepath}, or to find the
#' shapes that error). Each step does, for all shapes at once, what used to be done
#' shape by shape, with the same result.
#'
#' Returns the GPS points (\code{route_type} and units are set by the caller), the
#' error of each shape with a trip that can't be converted, and the messages of all
#' shapes, in order, as functions for the caller to run.
#' @noRd
feed_to_gps <- function(slice, routes, spatial_resolution, n_threads) {
  shape_ids <- slice$shape_ids
  n_shapes <- length(shape_ids)
  rank_of <- function(x) match(x, shape_ids, incomparables = NA)

  ## trips of each shape, in trips order, with their trip_number (the trip's index
  ## among the shape's trips); trips without a route_id are skipped
  trips <- data.table::data.table(
    shape_rank = rank_of(slice$trips$shape_id),
    trip_id = slice$trips$trip_id,
    route_id = slice$trips$route_id
  )[!is.na(shape_rank)]
  has_trips <- seq_len(n_shapes) %in% trips$shape_rank
  trips <- trips[!is.na(route_id)]
  has_route <- seq_len(n_shapes) %in% trips$shape_rank
  trip_numbers <- unique(trips[, .(shape_rank, trip_id)])
  trip_numbers[, trip_number := data.table::rowid(shape_rank)]

  ## stop_times rows of those trips, owned by the shape, in their original order (a
  ## join, so an NA trip_id matches the NA trip, as %chin% did)
  st <- data.table::data.table(
    shape_rank = rank_of(slice$owner),
    trip_id = slice$stop_times$trip_id,
    stop_sequence = slice$stop_times$stop_sequence,
    stop_id = slice$stop_times$stop_id,
    departure_time = slice$stop_times$departure_time,
    arrival_time = slice$stop_times$arrival_time
  )
  st <- trip_numbers[st, on = c("shape_rank", "trip_id"), nomatch = NULL]
  has_stops <- seq_len(n_shapes) %in% st$shape_rank

  ## stop patterns: stops are snapped once per pattern and cpp_expand_pattern() joins
  ## each trip's times by stop_sequence, which is only valid within a pattern.
  ## Patterns of a shape in order of first appearance among its trips sorted by
  ## trip_id; the first trip of a pattern gives its stops and template times
  pat <- st[, .(shape_rank, trip_id, trip_number, stop_sequence, stop_id)]
  data.table::setorderv(pat, c("shape_rank", "trip_id", "stop_sequence"))
  # the rows of each trip are contiguous, so trips with the same sequence of stops
  # get the same id in C++, comparing integer codes (no text keys, which could
  # make different sequences look the same)
  codes <- list(
    match(pat$stop_sequence, unique(pat$stop_sequence)),
    match(pat$stop_id, unique(pat$stop_id))
  )
  pat <- pat[, .N, by = c("shape_rank", "trip_id", "trip_number")]
  pat[, pattern_key := cpp_sequence_pattern_id(N, codes)]
  pat[, pattern := match(pattern_key, unique(pattern_key)), by = shape_rank]
  pat[, trip_rank := seq_len(.N), by = c("shape_rank", "pattern")]
  patterns <- unique(pat[, .(shape_rank, pattern)])
  patterns[, pattern_id := .I]
  pat[patterns, on = c("shape_rank", "pattern"), pattern_id := i.pattern_id]
  n_patterns <- nrow(patterns)
  n_trips <- tabulate(pat$pattern_id, nbins = n_patterns)

  ## stops of each pattern: the first trip's rows (an NA trip_id has none), with the
  ## coordinates of the last row of each stop_id in stops, sorted by stop_sequence
  first <- pat[
    trip_rank == 1L & !is.na(trip_id),
    .(shape_rank, trip_id, pattern_id)
  ]
  ps <- first[st, on = c("shape_rank", "trip_id"), nomatch = NULL]
  ps[
    slice$stops,
    on = "stop_id",
    c('stop_lat', 'stop_lon') := list(i.stop_lat, i.stop_lon)
  ] # add lat long info
  data.table::setorderv(ps, c("pattern_id", "stop_sequence"))

  ## the shapes in high resolution: gtfs2gps() segmentizes all shapes in one call,
  ## and only when that fails is each shape segmentized here
  points <- slice$points
  if (is.null(points)) {
    # only the shapes that pass the guards above, as each shape was segmentized after
    # them (an unused shape with a bad geometry is still just reported as unused)
    converting <- shape_ids[has_trips & has_route & has_stops]
    points <- list(shape_id = character(0), coords = matrix(numeric(0), 0, 2))
    if (length(converting) > 0) {
      shapes <- slice$shapes
      if (!is.null(shapes)) {
        shapes <- shapes[shapes$shape_id %in% converting, ]
      }
      new_shape <- suppressPackageStartupMessages(
        sf::st_segmentize(
          x = shapes,
          dfMaxLength = units::set_units(spatial_resolution / 1000, "km")
        )
      )
      points <- shape_points(new_shape)
    }
  }
  point_rank <- rank_of(points$shape_id)
  point_rows <- which(!is.na(point_rank))
  point_rows <- point_rows[order(point_rank[point_rows])]
  point_rank <- point_rank[point_rows]
  lon <- points$coords[point_rows, 1]
  lat <- points$coords[point_rows, 2]
  point_id <- data.table::rowid(point_rank)
  n_points <- tabulate(point_rank, nbins = n_shapes)
  point_from <- cumsum(c(0L, n_points))[seq_len(n_shapes)]

  ## distances along the shapes and positions of the stops of each pattern on its
  ## shape, both from gtfstools::interpolate_shape_dist_traveled() on the points in
  ## high resolution (great-circle distances on the {s2} sphere): each pattern is a
  ## trip of its shape, with the stops of its first trip
  ps_stop <- as.character(seq_len(nrow(ps)))
  located <- locate_stops(
    list(
      shapes = data.table::data.table(
        shape_id = as.character(seq_len(n_shapes))[point_rank],
        shape_pt_lat = lat,
        shape_pt_lon = lon,
        shape_pt_sequence = point_id
      ),
      trips = data.table::data.table(
        trip_id = as.character(seq_len(n_patterns)),
        shape_id = as.character(patterns$shape_rank)
      ),
      stop_times = data.table::data.table(
        trip_id = as.character(ps$pattern_id),
        stop_id = ps_stop,
        stop_sequence = data.table::rowid(ps$pattern_id)
      ),
      stops = data.table::data.table(
        stop_id = ps_stop,
        stop_lat = as.double(ps$stop_lat),
        stop_lon = as.double(ps$stop_lon)
      )
    ),
    n_threads
  )

  # points without coordinates have no distance and are dropped; dist is the
  # distance from the previous kept point of the same shape (0 at the first one)
  cumdist <- located$shapes$shape_dist_traveled
  kept <- !is.na(cumdist)
  kept_rank <- point_rank[kept]
  kept_cumdist <- cumdist[kept]
  dist <- rep(NA_real_, length(cumdist))
  dist[kept] <- data.table::fifelse(
    duplicated(kept_rank),
    kept_cumdist - data.table::shift(kept_cumdist),
    0
  )
  n_kept <- tabulate(kept_rank, nbins = n_shapes)
  kept_from <- cumsum(c(0L, n_kept))[seq_len(n_shapes)]
  shape_length <- rep(0, n_shapes)
  shape_length[n_kept > 0] <- kept_cumdist[
    kept_from[n_kept > 0] + n_kept[n_kept > 0]
  ]

  ## snap the stops of each pattern to the points of its shape
  # typed NA of the route_type column (NULL when routes has no route_type, and then
  # there is no column)
  route_type_na <- routes$route_type[NA_integer_]
  pos <- located$stop_times$shape_dist_traveled
  ps_shape <- patterns$shape_rank[ps$pattern_id]
  n_ps <- tabulate(ps$pattern_id, nbins = n_patterns)
  # gtfstools locates only patterns with two stops or more; a single stop (with
  # coordinates, on a shape with a length) goes to the start of the shape, so that
  # its pattern is reported below as one with fewer than two stops
  one <- n_ps[ps$pattern_id] == 1L &
    shape_length[ps_shape] > 0 &
    !is.na(ps$stop_lat) &
    !is.na(ps$stop_lon)
  pos[one] <- 0
  # a pattern is snapped when all its stops (at least one) have a position
  snapped_ok <- n_ps > 0 &
    tabulate(ps$pattern_id[is.na(pos)], nbins = n_patterns) == 0
  snapped_ref <- numeric(nrow(ps))
  sn <- snapped_ok[ps$pattern_id]
  if (any(sn)) {
    # each stop at the kept point nearest to its position (the first one of points
    # at the same distance), then moved forward where needed so that each stop has
    # a point of its own, as long as the shape has points left
    kp <- data.table::data.table(
      shape_rank = kept_rank,
      cumdist = kept_cumdist,
      kidx = data.table::rowid(kept_rank)
    )
    q <- data.table::data.table(
      shape_rank = ps_shape[sn],
      cumdist = pos[sn],
      pattern_id = ps$pattern_id[sn]
    )
    nearest <- kp[
      q,
      kidx,
      on = c("shape_rank", "cumdist"),
      roll = "nearest",
      mult = "first"
    ]
    q[, kidx := nearest]
    q[,
      kidx := pmin(
        cummax(kidx - seq_len(.N) + 1L) + seq_len(.N) - 1L,
        n_kept[shape_rank]
      ),
      by = pattern_id
    ]
    snapped_ref[sn] <- point_id[kept][kept_from[q$shape_rank] + q$kidx]
  }

  ## templates: the points of each pattern's shape, with the pattern's stops at
  ## their snapped point (two stops on one point: the last one in stop_sequence order)
  ok <- which(snapped_ok)
  tpl <- data.table::data.table(
    pattern_id = rep(ok, n_points[patterns$shape_rank[ok]]),
    point = sequence(
      n_points[patterns$shape_rank[ok]],
      from = point_from[patterns$shape_rank[ok]] + 1L
    )
  )
  tpl[, id := point_id[point]]
  ps[, ref := snapped_ref]
  tpl[
    ps[snapped_ok[pattern_id]],
    on = c("pattern_id", "id" = "ref"),
    ":="(
      stop_id = i.stop_id,
      stop_sequence = i.stop_sequence,
      departure_time = i.departure_time,
      arrival_time = i.arrival_time
    )
  ]
  tpl <- tpl[kept[point]]
  few_points <- snapped_ok & tabulate(tpl$pattern_id, nbins = n_patterns) < 2
  few_stops <- snapped_ok &
    !few_points &
    tabulate(tpl$pattern_id[!is.na(tpl$stop_sequence)], nbins = n_patterns) < 2
  good <- snapped_ok & !few_points & !few_stops
  tpl <- tpl[good[pattern_id]]
  tpl_size <- tabulate(tpl$pattern_id, nbins = n_patterns)
  tpl_from <- cumsum(c(0L, tpl_size))[seq_len(n_patterns)]

  ## the trips of the converted patterns, in output order (shape, trip_number), each
  ## with its stop_times rows in their original order (the last row with a
  ## duplicated stop_sequence wins the join in C++); an NA trip_id has no rows
  kt <- pat[
    good[pattern_id],
    .(shape_rank, trip_id, trip_number, pattern_id, trip_rank)
  ]
  data.table::setorderv(kt, c("shape_rank", "trip_number"))
  kt[, k := .I]
  kst <- kt[, .(shape_rank, trip_id, k)][
    st[!is.na(trip_id)],
    on = c("shape_rank", "trip_id"),
    nomatch = NULL
  ]
  data.table::setorderv(kst, "k")

  # all trips at once, in C++ (src/expand_pattern.cpp); its only error a user can
  # cause is an output above INT_MAX rows
  res <- tryCatch(
    cpp_expand_pattern(
      as.double(tpl$stop_sequence),
      as.integer(tpl$departure_time),
      as.integer(tpl$arrival_time),
      !is.na(tpl$stop_id),
      dist[tpl$point],
      cumdist[tpl$point],
      as.integer(tpl_from[kt$pattern_id]),
      as.integer(tpl_size[kt$pattern_id]),
      tabulate(kst$k, nbins = nrow(kt)),
      as.double(kst$stop_sequence),
      as.integer(kst$departure_time),
      as.integer(kst$arrival_time),
      capabilities("long.double"),
      as.integer(n_threads)
    ),
    error = function(e) {
      if (!startsWith(conditionMessage(e), "Too many GPS points")) {
        stop(e)
      }
      max_rows <- .Machine$integer.max
      cli::cli_abort(
        c(
          "Too many GPS points: the output would have more than {.val {max_rows}} rows.",
          "i" = "Use a larger {.arg spatial_resolution} (now {spatial_resolution} m) or convert fewer shapes at a time."
        ),
        class = "gtfs2gps_too_many_points_error",
        call = NULL
      )
    }
  )
  kt[, status := res$status]
  # the speeds checked below, counted per trip by cpp_expand_pattern() (before
  # kt is sorted again for the messages)
  kt[,
    c("n_na", "n_inf", "n_nonpos", "n_neg") := res[c(
      "n_na",
      "n_inf",
      "n_nonpos",
      "n_neg"
    )]
  ]

  ## a trip with fewer than two timed stops on its shape fails the shape: the first
  ## such trip in pattern order, as when the shape was converted pattern by pattern
  failing <- kt[status == 2L]
  data.table::setorderv(failing, c("pattern_id", "trip_rank"))
  failing <- failing[!duplicated(shape_rank)]
  failed <- seq_len(n_shapes) %in% failing$shape_rank
  errors <- lapply(failing$trip_id, function(tripid) {
    tryCatch(
      cli::cli_abort(
        "Trip {.val {tripid}} has fewer than two timed stops on its shape.", # nocov
        class = "gtfs2gps_trip_error"
      ), # nocov
      error = function(e) e
    )
  })
  names(errors) <- shape_ids[failing$shape_rank]

  # each snapped pattern used to add the typed NA route_type to its own table, up to
  # the shape's failing pattern, which warns once per pattern when routes has no
  # route_type
  if (is.null(route_type_na)) {
    last_pattern <- rep(Inf, n_shapes)
    last_pattern[failing$shape_rank] <- failing$pattern_id
    for (g in which(
      snapped_ok & seq_len(n_patterns) <= last_pattern[patterns$shape_rank]
    )) {
      data.table::data.table(id = 1L)[, route_type := route_type_na]
    }
  }

  ## the GPS points of the converted trips of the shapes that did not fail
  converted <- res$status == 0L
  keep <- converted & !failed[kt$shape_rank]
  n_rows <- res$n_rows[keep]
  # only the rows of a failed shape are dropped, which is rare
  if (!all(keep[converted])) {
    rows <- which(rep(keep[converted], res$n_rows[converted]))
    res[c("src", "dist", "speed", "timestamp", "cumtime")] <-
      lapply(res[c("src", "dist", "speed", "timestamp", "cumtime")], `[`, rows)
  }
  src <- res$src
  point <- tpl$point[src]
  ktk <- kt[keep]

  # route type of each converted trip, by shape: the last row of the trip in trips (with
  # a route_id) gives it, NA when its route is not in routes (a trip listed under two
  # shapes takes each shape's route). Routes without a route_type give no column
  route_type <- route_type_na
  if (!is.null(route_type_na)) {
    route_type <- route_type_na[0]
    if (sum(n_rows) > 0) {
      trip_rt <- unique(routes[, .(route_id, route_type)], by = "route_id")[
        slice$trips[!is.na(route_id), .(shape_id, trip_id, route_id)],
        on = "route_id"
      ]
      keys <- data.table::data.table(
        shape_id = shape_ids[ktk$shape_rank],
        trip_id = ktk$trip_id
      )
      route_type <- rep(
        trip_rt[keys, on = c("shape_id", "trip_id"), mult = "last", route_type],
        n_rows
      )
    }
  }

  # timestamps wrap at midnight (elapsed time is in cumtime)
  cols <- list(
    shape_id = rep(shape_ids[ktk$shape_rank], n_rows),
    id = sequence(n_rows),
    shape_pt_lon = lon[point],
    shape_pt_lat = lat[point],
    route_type = route_type,
    stop_id = tpl$stop_id[src],
    stop_sequence = tpl$stop_sequence[src],
    dist = res$dist,
    # rounded as the columns from cpp_expand_pattern(), once per shape point
    cumdist = round3(cumdist)[point],
    trip_id = rep(ktk$trip_id, n_rows),
    speed = res$speed,
    timestamp = structure(res$timestamp %% 86400L, class = "ITime"),
    cumtime = res$cumtime,
    trip_number = rep(ktk$trip_number, n_rows)
  )
  # without a route_type the column is left out, so that setcolorder() fails as it did
  if (is.null(route_type)) {
    cols$route_type <- NULL
  }
  # setDT() makes the table from these vectors without copying them (data.table()
  # copied all of them): none of them may refer to the slice or the input data
  gps <- data.table::setDT(cols)
  if (nrow(gps) > 0) {
    data.table::setcolorder(
      gps,
      c(
        "shape_id",
        "trip_id",
        "route_type",
        "id",
        "timestamp",
        "shape_pt_lon",
        "shape_pt_lat",
        "stop_id",
        "stop_sequence",
        "speed",
        "dist",
        "cumdist",
        "cumtime"
      )
    )
  }

  ## the messages of each shape, in the order they used to be shown
  # kept trips per shape (each has rows), rather than rows per shape
  n_out <- tabulate(ktk$shape_rank, nbins = n_shapes)
  n_inf <- n_neg <- integer(n_shapes)
  by_shape <- ktk[,
    .(inf = sum(n_inf), nonpos = sum(n_nonpos)),
    by = shape_rank
  ]
  n_inf[by_shape$shape_rank] <- by_shape$inf
  n_neg[by_shape$shape_rank] <- by_shape$nonpos
  patterns_of <- split(
    seq_len(n_patterns),
    factor(patterns$shape_rank, levels = seq_len(n_shapes))
  )
  data.table::setorderv(kt, c("pattern_id", "trip_rank"))
  trips_of <- split(
    seq_len(nrow(kt)),
    factor(kt$pattern_id, levels = seq_len(n_patterns))
  )

  messages <- lapply(seq_len(n_shapes), function(s) {
    shapeid <- shape_ids[s]
    if (!has_trips[s]) {
      return(list(inform(
        "Shape {.val {shapeid}} is not used by any trip. Ignoring it.",
        shapeid = shapeid
      )))
    }
    if (!has_route[s]) {
      return(list(inform(
        "Shape {.val {shapeid}} has no route_id. Ignoring it.",
        shapeid = shapeid
      )))
    }
    if (!has_stops[s]) {
      return(list(inform(
        "Shape {.val {shapeid}} has zero stops. Ignoring it.",
        shapeid = shapeid
      )))
    }
    out <- list()
    for (g in patterns_of[[s]]) {
      n <- n_trips[g]
      if (!snapped_ok[g]) {
        out <- c(
          out,
          inform(
            "Shape {.val {shapeid}}: {n} trip{?s} with a stop pattern that has no snapped stops. Ignoring {?it/them}.",
            shapeid = shapeid,
            n = n
          )
        )
      } else if (few_points[g]) {
        out <- c(
          out,
          inform(
            "Shape {.val {shapeid}}: {n} trip{?s} with less than two points after conversion. Ignoring {?it/them}.",
            shapeid = shapeid,
            n = n
          )
        )
      } else if (few_stops[g]) {
        out <- c(
          out,
          inform(
            "Shape {.val {shapeid}}: {n} trip{?s} with less than two stops after conversion. Ignoring {?it/them}.",
            shapeid = shapeid,
            n = n
          )
        )
      } else {
        # the trips skipped before the failing trip, if any, then nothing more
        k <- trips_of[[g]]
        fails <- which(kt$status[k] == 2L)
        if (length(fails) > 0) {
          k <- k[seq_len(fails[1] - 1L)]
        }
        for (tripid in kt$trip_id[k[kt$status[k] == 1L]]) {
          out <- c(
            out,
            inform(
              "Trip {.val {tripid}} has less than two stop_ids. Ignoring it.",
              tripid = tripid
            )
          )
        }
        if (length(fails) > 0) return(out)
      }
    }
    if (n_out[s] == 0) {
      return(c(
        out,
        inform(
          "Shape {.val {shapeid}}: no trip could be converted. Ignoring it.",
          shapeid = shapeid
        )
      ))
    }
    if (n_inf[s] > 0) {
      out <- c(
        out,
        inform(
          "{infinite_values} {.field speed} value{?s} {?is/are} Inf for shape {.val {shapeid}}.",
          infinite_values = n_inf[s],
          shapeid = shapeid
        )
      )
    }
    if (n_neg[s] > 0) {
      out <- c(
        out,
        inform(
          "{negative_values} {.field speed} value{?s} {?is/are} zero or negative for shape {.val {shapeid}}.",
          negative_values = n_neg[s],
          shapeid = shapeid
        )
      )
    }
    return(out)
  })

  if (nrow(gps) == 0) {
    gps <- NULL
  }
  return(list(
    gps = gps,
    errors = errors,
    messages = unlist(messages, recursive = FALSE),
    # the converted trips, in output order, with the counts gtfs2gps() reports on
    trips = ktk[, .(
      shape_id = shape_ids[shape_rank],
      trip_id,
      n_na,
      n_inf,
      n_neg
    )]
  ))
}

#' A message to show later: a function that calls cli::cli_inform() with the
#' values given here
#' @noRd
inform <- function(text, ...) {
  values <- list2env(list(...))
  return(function() cli::cli_inform(text, .envir = values))
}

#' The points of segmentized shapes: their shape_id and coordinates
#'
#' Read from the lines with sf::st_coordinates(), much faster than casting them
#' to points first. Its last column is the index of the feature (L1 for
#' LINESTRING, L2 for MULTILINESTRING), whatever the dimensions.
#' @noRd
shape_points <- function(x) {
  if (nrow(x) == 0) {
    return(list(shape_id = character(0), coords = matrix(numeric(0), 0, 2)))
  }
  xy <- sf::st_coordinates(x)
  return(list(
    shape_id = x$shape_id[xy[, ncol(xy)]],
    coords = xy[, 1:2, drop = FALSE]
  ))
}

#' Distances along the shapes and positions of the stops on them
#'
#' Runs gtfstools::interpolate_shape_dist_traveled() on a GTFS built by
#' feed_to_gps() in n_threads threads (gtfstools uses data.table's thread
#' count). Trips whose shape can't be used get NA positions, without its warning.
#' @noRd
locate_stops <- function(gtfs, n_threads) {
  old_threads <- data.table::setDTthreads(n_threads)
  on.exit(data.table::setDTthreads(old_threads), add = TRUE)
  return(withCallingHandlers(
    gtfstools::interpolate_shape_dist_traveled(gtfstools::as_dt_gtfs(gtfs)),
    gtfstools_trips_without_shape = function(w) invokeRestart("muffleWarning")
  ))
}

#' units of the GPS columns, set in place: the attribute and class that
#' units::set_units() gives, without copying the columns
#' @noRd
set_gps_units <- function(gps) {
  km_h <- attr(units::set_units(0, "km/h"), "units")
  m <- attr(units::set_units(0, "m"), "units")
  s <- attr(units::set_units(0, "s"), "units")
  data.table::setattr(gps[["speed"]], "units", km_h)
  data.table::setattr(gps[["speed"]], "class", "units")
  data.table::setattr(gps[["dist"]], "units", m)
  data.table::setattr(gps[["dist"]], "class", "units")
  data.table::setattr(gps[["cumdist"]], "units", m)
  data.table::setattr(gps[["cumdist"]], "class", "units")
  data.table::setattr(gps[["cumtime"]], "units", s)
  data.table::setattr(gps[["cumtime"]], "class", "units")
  return(invisible(gps))
}

#' x rounded to 3 decimals as round3() in src/expand_pattern.cpp does (NA and NaN
#' as they are)
#' @noRd
round3 <- function(x) {
  r <- round(x * 1000) / 1000
  r[is.na(x)] <- x[is.na(x)]
  return(r)
}
