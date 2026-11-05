#' @title Convert GTFS to GPS-like data given a spatial resolution
#'
#' @description Convert GTFS data to GPS format by sampling points using a
#' given spatial resolution. This function creates additional points in order
#' to guarantee that two points in a same trip will have at most a given
#' distance, indicated as a spatial resolution.
#'
#' Stops without times are placed along the shape at constant speed between
#' the timed stops. \code{\link[gtfstools]{fix_gtfs}} can clean a feed before
#' converting it (e.g. duplicated rows and unused ids), but the stop times it
#' interpolates may give spiky or infinite speeds here.
#'
#' @param gtfs_data A path to a GTFS file to be converted to GPS, or a GTFS
#'        data represented as a list of data.tables.
#' @param spatial_resolution The spatial resolution in meters: a number of at
#'        least 1, or a \code{units} length. Default is 100m. This function only
#'        creates points in order to guarantee that consecutive points are at most
#'        \code{spatial_resolution} metres apart. If a given shape
#'        has two consecutive points with a distance lower than the spatial resolution,
#'        the algorithm will not remove such points.
#' @param parallel This argument is deprecated and ignored. Please use argument
#'         ncores instead.
#' @param ncores Number of threads used. Defaults to 2. If \code{Inf}, it uses
#'        all threads available, as given by \code{data.table::getDTthreads()}.
#' @param strategy This argument is deprecated and ignored. Please use argument
#'        ncores instead.
#' @param filepath Output file path. As default, the output is returned when gtfs2gps
#'        finishes. When this argument is set, each shape is saved into a txt file
#'        within filepath, named after its \code{shape_id}. Characters that can't be
#'        in a file name on some systems (such as \code{/}, \code{:} or \code{*}) and
#'        \code{\%} are written as \code{\%XX}, their hexadecimal code, so \code{utils::URLdecode()} gives the id back
#'        (e.g. \code{"a/b"} is saved as \code{a\%2Fb.txt}). In this case, no output
#'        is returned. See argument compress for another option.
#' @param compress Argument that can be used only with filepath. When `TRUE`, it
#'        compresses the output files by saving them using `.rds` format. Default value is
#'        `FALSE`. Note that compress guarantees that the data saved will be read in the same way as it
#'        was created in R. If not compress, the txt extension requires the data to be converted
#'        from ITime to string, and therefore they need to be manually converted back to ITime to
#'        be properly handled by gtfs2gps.
#' @param continue Argument that can be used only with filepath. When TRUE, it
#'        skips processing the shape identifiers that were already saved into
#'        files. It is useful to continue processing a GTFS file that was stopped
#'        for some reason. Default value is `FALSE`.
#' @param snap_method This argument is deprecated and ignored. Stops are now
#'        located along the shapes with `gtfstools::interpolate_shape_dist_traveled()`
#'        (see details).
#' @param quiet Hide messages while processing the data. Defaults to `FALSE`.
#'
#' @details Before converting, the feed is cleaned with
#' `gtfstools::remove_duplicates()` and `gtfstools::remove_unused_ids()`, and trips
#' with an `NA` `trip_id` are dropped. Errors and warnings raised by the package
#' have classes starting with `gtfs2gps_` (e.g. `gtfs2gps_nothing_converted_error`),
#' and deprecation warnings with `deprecated_`, so they can be caught.
#'
#' After creating geometry points for a given shape id, the `gtfs2gps()`
#' function snaps the stops to the route geometry. The stops of each trip are
#' located along the shape with `gtfstools::interpolate_shape_dist_traveled()`,
#' which projects each stop onto the shape keeping the stops in their
#' `stop_sequence` order, so that loops and shapes that pass by the same place
#' more than once are handled. Each stop is then snapped to the nearest point of
#' the shape in high resolution, moved forward when needed so that each stop has
#' a point of its own. Distances are great-circle distances on the sphere used
#' by the s2 and sf packages, with a radius of 6,371,010 m.
#'
#' Each trip runs from its first to its last stop with a departure time: shape
#' points (and stops without times) before the first one and after the last one
#' have no time to be interpolated from, and are not returned. The `speed`,
#' `cumdist`, and `cumtime` are based on the difference of distance and time
#' between the current and previous row of the same trip. It means that the first
#' data point of each trip, at its first stop, represents a stationary vehicle,
#' with `dist`, `cumdist` and `cumtime` equal to zero: `cumdist` is the distance
#' travelled from the first stop. Unrealistic speeds are best fixed in the GTFS
#' before converting it, with `gtfstools::set_max_speed()` (and
#' `gtfstools::set_min_speed()`, in the development version of gtfstools). Two stops at the same place and time give an
#' `NA` speed.
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
#' `departure_time` are identical at the same stop). In this case,
#' `gtfstools::set_dwell_time()` or `gtfstools::set_min_dwell_time()` can set the
#' time vehicles spend at stops to embark/disembark passengers.
#'
#' To avoid division by zero, the minimum speed of vehicles in the output is
#' 1e-12 km/h, so that vehicles are never completely stopped.
#'
#' @return A `data.table`, where each row represents a GPS point. The following
#' columns are returned (units of measurement in parenthesis): dist and cumdist
#' (meters), cumtime (seconds), shape_pt_lon and shape_pt_lat (degrees), speed
#' (km/h), timestamp (`data.table::ITime`, wrapped at midnight). Speed, dist,
#' cumdist and cumtime are rounded to 3 decimal places (also when written to
#' filepath), except speeds closer to zero than that, which keep their value (such
#' as the 1e-12 km/h of stops). With `filepath`, each shape is written to a file
#' and `NULL` is returned.
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
  parallel = NULL,
  ncores = 2,
  strategy = NULL,
  filepath = NULL,
  compress = FALSE,
  snap_method = NULL,
  continue = FALSE,
  quiet = FALSE
) {
  checkmate::assert_flag(quiet)
  if (quiet) {
    # the user's call again, without quiet, so that errors name it and
    # substitute(gtfs_data) sees the user's object. Nothing above this line may
    # evaluate gtfs_data, or it would be evaluated twice
    cl <- match.call()
    cl$quiet <- NULL
    return(suppressMessages(eval(cl, parent.frame())))
  }

  if (!is.null(strategy)) {
    cli::cli_warn(
      c(
        "Argument {.arg strategy} is deprecated and will be removed in a future version.",
        "i" = "Use argument {.arg ncores} instead."
      ),
      class = "deprecated_strategy"
    )
  }

  if (!is.null(parallel)) {
    cli::cli_warn(
      c(
        "Argument {.arg parallel} is deprecated and ignored.",
        "i" = "Use {.arg ncores} to set the number of threads: {.code ncores = 1} runs sequentially and {.code ncores = Inf} uses all available threads."
      ),
      class = "deprecated_parallel"
    )
  }

  if (is.null(ncores)) {
    ncores <- 2
  } # back-compat: NULL was a valid value before
  if (!identical(ncores, Inf)) {
    checkmate::assert_count(ncores, positive = TRUE)
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
  checkmate::assert_flag(compress)
  checkmate::assert_flag(continue)
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
  # spatial_resolution is used in metres from here on (both st_segmentize() calls); a
  # units length is converted first
  if (inherits(spatial_resolution, "units")) {
    spatial_resolution <- units::drop_units(units::set_units(
      spatial_resolution,
      "m"
    ))
  }
  checkmate::assert_number(spatial_resolution, lower = 1, finite = TRUE)

  # deparsed only if a shape fails, and only when it names an object: under
  # do.call() it is the whole feed
  gtfs_data_expr <- substitute(gtfs_data)

  # Unzipping and reading GTFS.zip file
  if (is.character(gtfs_data)) {
    # the step's text is interpolated again when it ends, after gtfs_data is replaced
    gtfs_file <- basename(gtfs_data)
    cli::cli_progress_step("Unzipping and reading {.file {gtfs_file}}")
    gtfs_data <- read_gtfs(gtfszip = gtfs_data, quiet = TRUE)
  }

  # route_type is looked up for every trip; without it, every shape would fail
  missing_cols <- setdiff(c("route_id", "route_type"), names(gtfs_data$routes))
  if (length(missing_cols) > 0) {
    cli::cli_abort(
      c(
        "{.arg gtfs_data} has no valid {.file routes.txt}, which GTFS requires.",
        "x" = if (is.null(gtfs_data$routes)) {
          "The table is missing."
        } else {
          "Missing column{?s}: {.field {missing_cols}}."
        }
      ),
      class = "gtfs2gps_missing_routes_error"
    )
  }

  # do not change input data by reference
  gtfs_data <- data.table::copy(gtfs_data)

  # quick fix removing unused and duplicated ids; remove_unused_ids() errors on an NA
  # trip_id, and those trips produce no GPS points anyway
  gtfs_data$trips <- gtfs_data$trips[!is.na(trip_id)]
  gtfs_data$stop_times <- gtfs_data$stop_times[!is.na(trip_id)]
  gtfs_data <- gtfstools::remove_duplicates(gtfs_data)
  gtfs_data <- gtfstools::remove_unused_ids(gtfs_data)

  convertible <- gtfs_data$trips$shape_id %chin%
    gtfs_data$shapes$shape_id &
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
      !file.exists(paste0(filepath, "/", shape_file_name(shape_ids), extension))
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

  n_threads <- if (is.infinite(ncores)) data.table::getDTthreads() else ncores
  n_threads <- as.integer(n_threads)

  # threads are only used when the package was compiled with OpenMP
  n_used <- if (cpp_openmp_available()) n_threads else 1L
  cli::cli_inform("Using {n_used} thread{?s}")

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
                file = paste0(filepath, "/", shape_file_name(shapeid), ".rds"),
                compress = TRUE
              )
            } else {
              data.table::fwrite(
                x = r$gps,
                file = paste0(filepath, "/", shape_file_name(shapeid), ".txt")
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
    # the user's object when the call names one (not "." of a magrittr pipe, .x of a
    # purrr lambda, nor ..1 or X[[i]] from lapply() and friends)
    original_gtfs_data_arg <- "<your gtfs data>"
    if (is.name(gtfs_data_expr) &&
        !grepl("^([.]|[.]x|[.][.][0-9]+)$", as.character(gtfs_data_expr))) {
      original_gtfs_data_arg <- as.character(gtfs_data_expr)
    }

    # ids and error texts are values interpolated by cli, never parsed as markup
    errs <- vapply(msgs, conditionMessage, character(1))
    shape_bullets <- vapply(
      seq_along(badShapes),
      function(i) {
        id <- badShapes[i]
        err <- errs[i]
        cli::format_inline("{.val {id}}: {err}")
      },
      character(1)
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

    names(code) <- rep(" ", length(code))

    # rlang::warn() rather than cli::cli_warn(): cli wraps every line at the console
    # width, which would break the lines of code users copy. cli still formats the
    # other parts
    rlang::warn(
      c(
        cli::format_inline(
          "Some internal bug occurred while converting {length(badShapes)} shape{?s}."
        ),
        shape_bullets,
        "i" = cli::format_inline(
          "Please open an issue at {.url https://github.com/ipea/gtfs2gps/issues/new} ",
          "and attach a subset of your data created with:"
        ),
        code
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
    # scanning every row of output. Trips start and end at timed stops (#260), so an
    # NA speed comes from the data (two stops at the same time and place)
    if (sum(done_trips$n_na) > 0) {
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
