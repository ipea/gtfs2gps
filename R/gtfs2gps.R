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
  kt[, c("n_na", "n_inf", "n_nonpos", "n_neg") := res[c("n_na", "n_inf", "n_nonpos", "n_neg")]]

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
    cumdist = cumdist[point],
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
  by_shape <- ktk[, .(inf = sum(n_inf), nonpos = sum(n_nonpos)), by = shape_rank]
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
    trips = ktk[, .(shape_id = shape_ids[shape_rank], trip_id, n_na, n_inf, n_neg)]
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

#' @title Convert GTFS to GPS-like data given a spatial resolution
#'
#' @description Convert GTFS data to GPS format by sampling points using a given
#' spatial resolution. This function creates additional points in order to
#' guarantee that two points in a same trip will have at most a given
#' distance, indicated as a spatial resolution.
#'
#' Stops without times are placed along the shape at constant speed between the
#' timed stops. \code{\link[gtfstools]{fix_gtfs}} can clean a feed before
#' converting it (e.g. duplicated rows and unused ids), but the stop times it
#' interpolates may give spiky or infinite speeds here.
#'
#' @param gtfs_data A path to a GTFS file to be converted to GPS, or a GTFS data
#' represented as a list of data.tables.
#' @param spatial_resolution The spatial resolution in meters: a number of at
#' least 1, or a \code{units} length. Default is 100m.
#' This function only creates points in order to guarantee that the minimum
#' distance between two consecutive points will be at most the
#' spatial_resolution. If a given shape has two consecutive points with a
#' distance lower than the spatial resolution, the algorithm will not remove
#' such points.
#' @param parallel Decides whether the function should run in parallel. Defaults to FALSE.
#' When TRUE, the points of the trips are computed in several threads of the
#' current R session (when the package was compiled with OpenMP). The result is
#' the same either way.
#' @param ncores Number of threads to be used in parallel execution. When
#'        `parallel = FALSE`, this argument is ignored. When `parallel = TRUE`,
#'        then by default the function uses as many threads as
#'        `data.table::getDTthreads()`.
#' @param strategy This argument is deprecated and ignored. Please use arguments
#' parallel and ncores instead.
#' @param filepath Output file path. As default, the output is returned when gtfs2gps finishes.
#' When this argument is set, each route is saved into a txt file within filepath,
#' with the name equals to its id. In this case, no output is returned. See argument
#' compress for another option.
#' @param compress Argument that can be used only with filepath. When TRUE, it
#' compresses the output files by saving them using rds format. Default value is FALSE.
#' Note that compress guarantees that the data saved will be read in the same way as it
#' was created in R. If not compress, the txt extension requires the data to be converted
#' from ITime to string, and therefore they need to be manually converted back to ITime to
#' be properly handled by gtfs2gps.
#' @param continue Argument that can be used only with filepath. When TRUE, it
#'        skips processing the shape identifiers that were already saved into
#'        files. It is useful to continue processing a GTFS file that was stopped
#'        for some reason. Default value is FALSE.
#' @param snap_method This argument is deprecated and ignored. Stops are now
#' located along the shapes with `gtfstools::interpolate_shape_dist_traveled()`
#' (see details).
#' @param quiet Hide messages while processing the data? Defaults to FALSE.
#'
#' @details After creating geometry points for a given shape id, the `gtfs2gps()`
#' function snaps the stops to the route geometry. The stops of each trip are
#' located along the shape with `gtfstools::interpolate_shape_dist_traveled()`,
#' which projects each stop onto the shape keeping the stops in their
#' `stop_sequence` order, so that loops and shapes that pass by the same place
#' more than once are handled. Each stop is then snapped to the nearest point of
#' the shape in high resolution, moved forward when needed so that each stop has
#' a point of its own. Distances are great-circle distances on the sphere used
#' by the s2 and sf packages, with a radius of 6,371,010 m.
#'
#' The `speed`, `cumdist`, and `cumtime` are based on the difference of distance
#' and time between the current and previous row of the same trip. It means that
#' the first data point at the first stop of each trip represents a stationary
#' vehicle. The `adjust_speed()` function can be used to post-process the output
#' to replace eventual `NA` values in the `speed` column.
#'
#' Each stop is presented as two data points for each trip in the output. The
#' `timestamp` value in the first data point represents the time when the
#' vehicle arrived at that stop (corresponding the `arrival_time` column in the
#' `stop_times.txt` file), while the `timestamp` in the second data point
#' represents the time when the vehicle departed from that stop (corresponding
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
#' poa_gps <- gtfs2gps(gtfs, quiet = TRUE)
#'
gtfs2gps <- function(
  gtfs_data,
  spatial_resolution = 100,
  parallel = FALSE,
  ncores = NULL,
  strategy = NULL,
  filepath = NULL,
  compress = FALSE,
  snap_method = NULL,
  continue = FALSE,
  quiet = FALSE
) {
  if (quiet) {
    return(suppressMessages(gtfs2gps(
      gtfs_data,
      spatial_resolution,
      parallel,
      ncores,
      strategy,
      filepath,
      compress,
      snap_method,
      continue
    )))
  }

  if (!is.null(strategy)) {
    cli::cli_warn(
      c(
        "Argument {.arg strategy} is deprecated and will be removed in a future version.",
        "i" = "Use arguments {.arg parallel} and {.arg ncores} instead."
      ),
      class = "deprecated_strategy"
    )
  }

  if (!is.null(snap_method)) {
    cli::cli_warn(
      c(
        "Argument {.arg snap_method} is deprecated and will be removed in a future version.",
        "i" = "Stops are located along the shapes with {.fn gtfstools::interpolate_shape_dist_traveled}."
      ),
      class = "deprecated_snap_method"
    )
  }

  ###### PART 1. Load and prepare data inputs ------------------------------------
  if (compress & is.null(filepath)) {
    cli::cli_abort(
      "Cannot use argument {.arg compress} without passing a {.arg filepath}.",
      class = "gtfs2gps_filepath_error"
    )
  }

  if (continue & is.null(filepath)) {
    cli::cli_abort(
      "Cannot use argument {.arg continue} without passing a {.arg filepath}.",
      class = "gtfs2gps_filepath_error"
    )
  }

  if (!is.null(filepath)) {
    checkmate::assert_directory_exists(filepath, access = "w")
  }
  checkmate::assert_flag(parallel)
  # spatial_resolution is used in metres from here on (both st_segmentize() calls); a
  # units length is converted first
  if (inherits(spatial_resolution, "units")) {
    spatial_resolution <- units::drop_units(units::set_units(
      spatial_resolution,
      "m"
    ))
  }
  checkmate::assert_number(spatial_resolution, lower = 1, finite = TRUE)

  original_gtfs_data_arg <- paste(
    deparse(substitute(gtfs_data)),
    collapse = " "
  )

  # Unzipping and reading GTFS.zip file
  if (is.character(gtfs_data)) {
    # the step's text is interpolated again when it ends, after gtfs_data is replaced
    gtfs_file <- basename(gtfs_data)
    cli::cli_progress_step("Unzipping and reading {.file {gtfs_file}}")
    gtfs_data <- read_gtfs(gtfszip = gtfs_data)
  }

  # do not change input data by reference
  gtfs_data <- data.table::copy(gtfs_data)

  # quick fix removing unsed and duplicated ids; remove_unused_ids() errors on an NA
  # trip_id, and those trips produce no GPS points anyway
  gtfs_data$trips <- gtfs_data$trips[!is.na(trip_id)]
  gtfs_data$stop_times <- gtfs_data$stop_times[!is.na(trip_id)]
  gtfs_data <- gtfstools::remove_duplicates(gtfs_data)
  gtfs_data <- gtfstools::remove_unused_ids(gtfs_data)

  convertible <- gtfs_data$trips$shape_id %chin% gtfs_data$shapes$shape_id &
    gtfs_data$trips$trip_id %chin% gtfs_data$stop_times$trip_id
  if (!any(convertible)) {
    cli::cli_abort(
      c(
        "There is nothing to convert in {.arg gtfs_data}.",
        "x" = "No trip has both a shape in {.file shapes.txt} and stops in {.file stop_times.txt}."
      ),
      class = "gtfs2gps_nothing_converted_error"
    )
  }

  # if gtfs is frequency-based, then convert it to stop times
  if (test_gtfs_freq(gtfs_data) == 'frequency') {
    gtfs_data <- gtfstools::frequencies_to_stop_times(gtfs_data)
  }

  # convert departure and arrival times from strings to seconds
  gtfs_data <- stop_times_to_seconds(gtfs_data)

  # Convert all shapes into sf objects
  cli::cli_progress_step("Converting shapes to sf objects")
  shapes_sf <- shapes_as_sf(gtfs_data)

  ###### PART 2. The whole feed, or one slice per shape ---------------------------
  # shape_id is character (shapes_as_sf() requires it), so the split groups are
  # indexed by name
  all_shapeids <- unique(shapes_sf$shape_id)
  # trips with NA route_id are kept: the guards in feed_to_gps() handle them as before
  trips <- gtfs_data$trips[shape_id %chin% all_shapeids]
  # each stop_times row belongs to the first shape listing its trip
  owner <- trips$shape_id[match(gtfs_data$stop_times$trip_id, trips$trip_id)]

  # all shapes in high resolution in one call, much faster than one call per shape;
  # if it fails, each shape is converted on its own and segmentized in feed_to_gps(),
  # so that an error fails only that shape. Shapes without trips (or already saved,
  # with continue) are segmentized too, so a geometry that only warns now warns
  # here. lwgeom attaches sf, whose startup message furrr used to hide when the
  # shapes were segmentized in its futures
  points <- tryCatch(
    {
      pts <- suppressPackageStartupMessages(
        sf::st_segmentize(
          x = shapes_sf,
          dfMaxLength = units::set_units(spatial_resolution / 1000, "km")
        )
      )
      shape_points(pts)
    },
    error = function(e) NULL
  )

  # shapes already saved are skipped
  shape_ids <- all_shapeids
  if (continue) {
    extension <- ifelse(compress, ".rds", ".txt")
    shape_ids <- shape_ids[
      !file.exists(paste0(filepath, "/", shape_ids, extension))
    ]
  }

  # one slice per shape: a shape missing from a split gets a typed empty table, so
  # that the guards in feed_to_gps() report it exactly as before; groups are looked
  # up by position, as `[[id]]` never matches the name ""
  shape_slices <- function() {
    pick <- function(groups, id, template) {
      i <- match(id, names(groups))
      if (is.na(i)) {
        return(template[0])
      }
      return(groups[[i]])
    }
    # split() drops the rows of other trips (NA) and keeps the row order within each shape
    st_by_shape <- split(gtfs_data$stop_times, f = owner)
    trips_by_shape <- split(trips, by = "shape_id")
    if (is.null(points)) {
      shape_by_shape <- split(shapes_sf, shapes_sf$shape_id)
    } else {
      point_rows <- split(seq_len(nrow(points$coords)), points$shape_id)
    }
    return(lapply(shape_ids, function(id) {
      slice <- list(
        shape_ids = id,
        trips = pick(trips_by_shape, id, gtfs_data$trips),
        stop_times = pick(st_by_shape, id, gtfs_data$stop_times),
        stops = gtfs_data$stops
      )
      slice$owner <- rep(id, nrow(slice$stop_times))
      if (is.null(points)) {
        slice$shapes <- shape_by_shape[[match(id, names(shape_by_shape))]]
      } else {
        i <- match(id, names(point_rows))
        r <- if (is.na(i)) integer(0) else point_rows[[i]]
        slice$points <- list(
          shape_id = points$shape_id[r],
          coords = points$coords[r, , drop = FALSE]
        )
      }
      return(slice)
    }))
  }

  ###### PART 3. Convert the shapes ----------------------------------------------

  n_threads <- 1L
  if (parallel) {
    checkmate::assert_count(ncores, positive = TRUE, null.ok = TRUE)
    if (is.null(ncores)) {
      ncores <- data.table::getDTthreads()
    }
    n_threads <- as.integer(min(ncores, .Machine$integer.max))

    # threads are only used when the package was compiled with OpenMP
    n_used <- if (cpp_openmp_available()) n_threads else 1L
    cli::cli_inform("Using {n_used} thread{?s}")
  }

  cli::cli_progress_step("Processing the data")
  convert <- function(slice) {
    feed_to_gps(slice, gtfs_data$routes, spatial_resolution, n_threads)
  }
  bad_ids <- character(0)
  n_written <- 0L
  bad_errors <- list()
  result <- NULL

  # all shapes at once. Its warnings are kept until it succeeds: if it fails, each
  # shape is converted on its own, which warns again
  if (is.null(filepath) && !is.null(points)) {
    whole <- list(
      shape_ids = shape_ids,
      trips = trips,
      stop_times = gtfs_data$stop_times,
      owner = owner,
      stops = gtfs_data$stops,
      points = points
    )
    kept <- new.env()
    kept$warnings <- list()
    result <- tryCatch(
      withCallingHandlers(convert(whole), warning = function(w) {
        kept$warnings[[length(kept$warnings) + 1L]] <- w
        invokeRestart("muffleWarning")
      }),
      error = function(e) {
        # shape by shape would not help: the output would be just as large
        if (inherits(e, "gtfs2gps_too_many_points_error")) {
          stop(e)
        }
        NULL
      }
    )
    if (!is.null(result)) {
      # the original conditions, with their classes (not new base warnings)
      for (w in kept$warnings) {
        warning(w)
      }
      for (m in result$messages) {
        m()
      }
      bad_ids <- names(result$errors)
      bad_errors <- unname(result$errors)
      output <- result$gps
      done_trips <- result$trips
    }
  }

  # one shape at a time: with filepath, or to find the shapes that fail
  if (is.null(result)) {
    outputs <- list()
    outputs_trips <- list()
    slices <- shape_slices()
    # this bar closes the "Processing the data" step (one cli progress per frame);
    # the update comes first because the loop uses next
    cli::cli_progress_bar("Converting shapes", total = length(slices))
    for (slice in slices) {
      cli::cli_progress_update()
      r <- tryCatch(convert(slice), error = function(e) e)
      if (inherits(r, "gtfs2gps_too_many_points_error")) {
        stop(r)
      }
      if (inherits(r, "error")) {
        bad_ids <- c(bad_ids, slice$shape_ids)
        bad_errors <- c(bad_errors, list(r))
        next
      }
      for (m in r$messages) {
        m()
      }
      bad_ids <- c(bad_ids, names(r$errors))
      bad_errors <- c(bad_errors, unname(r$errors))
      if (is.null(r$gps)) {
        next
      }

      if (!is.null(filepath)) {
        # Write object; an error fails only this shape
        shapeid <- slice$shape_ids
        written <- tryCatch(
          {
            set_gps_units(r$gps)
            if (compress) {
              saveRDS(
                object = r$gps,
                file = paste0(filepath, "/", shapeid, ".rds"),
                compress = TRUE
              )
            } else {
              data.table::fwrite(
                x = r$gps,
                file = paste0(filepath, "/", shapeid, ".txt")
              )
            }
            NULL
          },
          error = function(e) e
        )
        if (!is.null(written)) {
          bad_ids <- c(bad_ids, shapeid)
          bad_errors <- c(bad_errors, list(written))
        } else {
          n_written <- n_written + 1L
        }
      } else {
        outputs[[length(outputs) + 1L]] <- r$gps
        outputs_trips[[length(outputs_trips) + 1L]] <- r$trips
      }
    }
    output <- data.table::rbindlist(outputs)
    done_trips <- data.table::rbindlist(outputs_trips)
  }

  # the shapes in the order of all_shapeids
  o <- order(match(bad_ids, all_shapeids))
  badShapes <- bad_ids[o]
  msgs <- bad_errors[o]

  if (length(badShapes) > 0) {
    # "gtfs_data" is what the quiet = TRUE recursion sees instead of the user's name
    if (original_gtfs_data_arg %in% c(".", "gtfs_data")) {
      original_gtfs_data_arg <- "<your gtfs data>"
    }

    # ids and error texts are interpolated by index, never parsed as cli markup
    errs <- vapply(msgs, conditionMessage, character(1))
    shape_bullets <- paste0(
      "{.val {badShapes[",
      seq_along(badShapes),
      "]}}: {errs[",
      seq_along(badShapes),
      "]}"
    )
    names(shape_bullets) <- rep("x", length(badShapes))
    code <- c(
      paste0("ids <- ", paste(deparse(badShapes), collapse = "")),
      paste0(
        "data <- gtfstools::filter_by_shape_id(",
        original_gtfs_data_arg,
        ", ids)"
      ),
      "gtfs2gps::write_gtfs(data, 'shapes_with_error.zip')"
    )

    cli::cli_warn(
      c(
        "Some internal bug occurred while converting {length(badShapes)} shape{?s}.",
        shape_bullets,
        "i" = paste(
          "Please open an issue at {.url https://github.com/ipea/gtfs2gps/issues/new}",
          "and attach a subset of your data created with:"
        ),
        " " = "{.code {code[1]}}",
        " " = "{.code {code[2]}}",
        " " = "{.code {code[3]}}"
      ),
      class = "gtfs2gps_shape_error"
    )
  }

  # no shape converted (with continue, shapes already saved count as converted)
  if (is.null(filepath)) {
    nothing <- is.null(output) || nrow(output) == 0
  } else {
    nothing <- n_written == 0 && length(shape_ids) == length(all_shapeids)
  }
  if (nothing) {
    cli::cli_abort(
      c(
        "None of the {length(all_shapeids)} shape{?s} in {.arg gtfs_data} could be converted.",
        "i" = "The warnings above, and the messages hidden by {.code quiet = TRUE}, say why."
      ),
      class = "gtfs2gps_nothing_converted_error"
    )
  }

  total_shapes <- data.table::uniqueN(gtfs_data$shapes$shape_id)
  # from the converted trips (each has rows in output), not from the output rows
  processed_shapes <- data.table::uniqueN(done_trips$shape_id)

  if (processed_shapes < total_shapes && is.null(filepath)) {
    perc <- round(processed_shapes / total_shapes * 100, 2)
    cli::cli_inform(
      "{processed_shapes} out of {total_shapes} shapes ({perc}%) were properly processed."
    )
  }

  total_trips <- data.table::uniqueN(gtfs_data$trips$trip_id)
  processed_trips <- data.table::uniqueN(done_trips$trip_id)

  if (processed_trips < total_trips && is.null(filepath)) {
    perc <- round(processed_trips / total_trips * 100, 2)
    cli::cli_inform(
      "{processed_trips} out of {total_trips} trips ({perc}%) were properly processed."
    )
  }

  if (is.null(filepath)) {
    set_gps_units(output)

    # the speed checks use the counts per trip from cpp_expand_pattern() instead of
    # scanning every row of output
    if (sum(done_trips$n_na) > 1) {
      cli::cli_inform("Some {.field speed} values are NA in the returned data.")
    }

    if (any(done_trips$n_inf > 0)) {
      cli::cli_inform(
        "Some {.field speed} values are Inf in the returned data."
      )
    }

    # check if there are any trips with negative speed
    trips_negative_speed <- unique(done_trips$trip_id[done_trips$n_neg > 0])

    if (length(trips_negative_speed) > 0) {
      cli::cli_inform(
        "There are negative speeds reported in the GTFS for the following {.field trip_id}s: {.val {cli::cli_vec(trips_negative_speed, list('vec-trunc' = Inf))}}"
      )
    }

    return(output)
  } else {
    return(NULL)
  }
}
