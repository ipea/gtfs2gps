# Changelog

## gtfs2gps (development version)

- Major changes
  - [`gtfs2gps()`](https://ipea.github.io/gtfs2gps/dev/reference/gtfs2gps.md)
    is much faster and uses less memory. Compared with v2.1-4
    (sequential runs), it is about 9× faster on the bundled poa feed,
    500× on the São Paulo feed, and 1,000× on a full Fortaleza feed (13M
    points: 95 min → 6 s). All shapes are converted in one pass, and the
    GPS points are computed in compiled code ({cpp11} replaces {Rcpp}).
  - [`gtfs2gps()`](https://ipea.github.io/gtfs2gps/dev/reference/gtfs2gps.md)
    no longer uses {future} workers, which were slower than a sequential
    run; this also removes the “globals exceed the maximum allowed size”
    failure ([\#277](https://github.com/ipea/gtfs2gps/issues/277)). The
    compiled step now runs in `ncores` threads when the package is built
    with OpenMP: the default is 2, and `ncores = Inf` uses all threads
    ([`data.table::getDTthreads()`](https://rdrr.io/pkg/data.table/man/openmp-utils.html)).
    A `future::plan()` is no longer used. Arguments `parallel` and
    `strategy` are deprecated and ignored, with a warning: use
    `ncores = 1` to run sequentially and `ncores = Inf` instead of
    `parallel = TRUE`.
  - Stops are located along the shapes with
    [`gtfstools::interpolate_shape_dist_traveled()`](https://ipea.github.io/gtfstools/reference/interpolate_shape_dist_traveled.html),
    which keeps them in `stop_sequence` order. Stop patterns are no
    longer dropped because a stop is far from the shape, loops are
    handled, and the result no longer depends on `spatial_resolution`.
    Distances use the sphere of {s2}/{sf}, so `dist`, `cumdist` and
    `speed` are about 0.11% smaller. `snap_method` is deprecated and
    ignored.
  - Fixed two bugs with shapes used by several trips: the trips of every
    route sharing a shape are now converted (only the first route’s
    were, e.g. 170 of the 348 trips in the Berlin feed), and trips with
    a different stop pattern no longer get their times attached to the
    wrong stops. `trip_number` now counts all trips of a shape.
  - Output changes: `speed`, `dist`, `cumdist` and `cumtime` are rounded
    to 3 decimals (stops keep their speed of 1e-12 km/h), and timestamps
    wrap at midnight (use `cumtime` for elapsed time).
  - Each trip now starts and ends at its first and last timed stop, so
    the `NA` speeds and times that the points before and after them had
    are gone, and `cumdist` is measured from the first stop. Shape
    points and untimed stops outside that span are no longer returned
    (nor the `"-"` segments of
    [`gps_as_sflinestring()`](https://ipea.github.io/gtfs2gps/dev/reference/gps_as_sflinestring.md)
    before the first and after the last stop), so the output no longer
    covers the whole shape (use
    [`gtfstools::get_shapes_geometry()`](https://ipea.github.io/gtfstools/reference/get_shapes_geometry.html)
    for that) and shouldn’t be mixed with files written by older
    versions when using `continue = TRUE`. The message “Some speed
    values are NA” now only appears when the data give an `NA` speed.
    Closes [\#260](https://github.com/ipea/gtfs2gps/issues/260).
  - [`gtfs2gps()`](https://ipea.github.io/gtfs2gps/dev/reference/gtfs2gps.md)
    first drops duplicated rows and unused ids
    ([`gtfstools::remove_duplicates()`](https://ipea.github.io/gtfstools/reference/remove_duplicates.html)
    and `remove_unused_ids()`) and ignores trips with an `NA` `trip_id`.
    It raises classed errors when `routes.txt` is missing or incomplete
    (`gtfs2gps_missing_routes_error`), when nothing can be converted
    (`gtfs2gps_nothing_converted_error`; it used to return `NULL`), and
    when the output would exceed R’s row limit
    (`gtfs2gps_too_many_points_error`).
  - Deprecated, to be removed in a future version, each with a warning
    of class `deprecated_<name>`:
    [`gtfs_shapes_as_sf()`](https://ipea.github.io/gtfs2gps/dev/reference/gtfs_shapes_as_sf.md)
    and
    [`gtfs_stops_as_sf()`](https://ipea.github.io/gtfs2gps/dev/reference/gtfs_stops_as_sf.md)
    (use
    [`gtfstools::get_shapes_geometry()`](https://ipea.github.io/gtfstools/reference/get_shapes_geometry.html),
    `get_shape_length()` and `get_stops_geometry()`);
    [`remove_invalid()`](https://ipea.github.io/gtfs2gps/dev/reference/remove_invalid.md)
    (use
    [`gtfstools::remove_duplicates()`](https://ipea.github.io/gtfstools/reference/remove_duplicates.html)
    and `remove_unused_ids()`, which keep trips whose shape or route is
    missing); and
    [`filter_valid_stop_times()`](https://ipea.github.io/gtfs2gps/dev/reference/filter_valid_stop_times.md).
  - Fixed
    [`adjust_speed()`](https://ipea.github.io/gtfs2gps/dev/reference/adjust_speed.md),
    which shifted timestamps even when no speed was replaced, made them
    run backwards before the first stop, and dropped dwell times. It no
    longer adds a `time` column and raises classed errors for invalid
    speeds.
  - Fixed
    [`gps_as_sflinestring()`](https://ipea.github.io/gtfs2gps/dev/reference/gps_as_sflinestring.md),
    which split trips only at timed stops (2 segments instead of 89 in
    its example). It now returns one segment per interval between
    consecutive stops.
  - Requires R \>= 4.1.0 and gtfstools \>= 2.0.0. With gtfstools 2.0.0,
    no departure is created at a frequency’s `end_time` (exclusive in
    GTFS), and malformed times (e.g. `"05:21"`, or minutes of 60 or
    more) are treated as missing, with a warning of class
    `gtfstools_malformed_time`.
- Minor changes
  - [`filter_single_trip()`](https://ipea.github.io/gtfs2gps/dev/reference/filter_single_trip.md)
    uses
    [`gtfstools::filter_by_trip_id()`](https://ipea.github.io/gtfstools/reference/filter_by_trip_id.html):
    the other tables keep only the rows used by the kept trips, and the
    input must be a GTFS object, as returned by
    [`read_gtfs()`](https://ipea.github.io/gtfs2gps/dev/reference/read_gtfs.md).
  - [`gps_as_sfpoints()`](https://ipea.github.io/gtfs2gps/dev/reference/gps_as_sfpoints.md)
    transforms the points to `crs` instead of relabelling them, so
    `crs = NA` is no longer accepted.
  - [`read_gtfs()`](https://ipea.github.io/gtfs2gps/dev/reference/read_gtfs.md)
    keeps all columns of `routes.txt`, reads feeds without `agency_id`
    or `route_short_name`, drops a header-only `frequencies.txt`, and
    raises `gtfs2gps_empty_file_error` for empty mandatory files.
  - [`write_gtfs()`](https://ipea.github.io/gtfs2gps/dev/reference/write_gtfs.md)
    respects `overwrite = FALSE` (error `gtfs2gps_file_exists_error`),
    gains `compression_level`, and documents the default of `quiet`
    correctly.
  - [`adjust_arrival_departure()`](https://ipea.github.io/gtfs2gps/dev/reference/adjust_arrival_departure.md)
    no longer modifies its input or writes negative times near midnight,
    rejects a negative `min_lag`, and rounds it to whole seconds.
  - `gtfs2gps(filepath)` writes shapes whose `shape_id` can’t be a file
    name (e.g. `"a/b"`, which pointed into a folder that does not
    exist): `/`, `\`, `:`, `*`, `?`, `"`, `<`, `>`, `|` and `%` are
    written as `%XX` (`a%2Fb.txt`), and
    [`utils::URLdecode()`](https://rdrr.io/r/utils/URLencode.html) gives
    the id back.
  - `gtfs2gps(continue = TRUE, compress = TRUE)` now skips shapes
    already saved (it looked for `.rda` files instead of `.rds`).
  - `spatial_resolution` can be a `units` length and must be at least 1
    metre. `compress`, `continue` and `quiet` must be a single `TRUE` or
    `FALSE`, `filepath` a writable directory, and
    [`append_height()`](https://ipea.github.io/gtfs2gps/dev/reference/append_height.md)’s
    `heightfile` an existing file;
    [`gps_as_sfpoints()`](https://ipea.github.io/gtfs2gps/dev/reference/gps_as_sfpoints.md)
    and
    [`gps_as_sflinestring()`](https://ipea.github.io/gtfs2gps/dev/reference/gps_as_sflinestring.md)
    reject empty input.
  - Messages, warnings and errors use {cli}, many with a class. Shapes
    that fail are reported in a warning of class `gtfs2gps_shape_error`,
    also when running in several threads. {cli} and {rlang} are new
    dependencies; {furrr}, {future}, {parallelly}, {progressr} and
    {Rcpp} are no longer used.
  - Loading the package no longer changes data.table’s options and
    number of threads.
  - A `trip_id` listed under two shapes (invalid GTFS) is converted
    once, with its first shape.

## gtfs2gps v2.1-2

CRAN release: 2024-10-08

- Minor changes
  - puts package back on CRAN
  - remove {magrittr} from Suggests
  - Clarifies in the documentation the default behavior of the parameter
    `ncores`. closes
    [\#271](https://github.com/ipea/gtfs2gps/issues/271). When
    `parallel = FALSE`, this argument is ignored. When
    `parallel = TRUE`, then by default the function uses all available
    cores minus one.

## gtfs2gps v2.1-1

CRAN release: 2023-04-28

- Major changes
  - Filter functions were removed from the package because gtfstools
    already implements them
  - Function `gtfs2gps` now uses `parallel = TRUE` by default.
  - Function `gtfs2gps` now uses
    [`gtfstools::frequencies_to_stop_times()`](https://ipea.github.io/gtfstools/reference/frequencies_to_stop_times.html)
    to convert. frequency-based GTFS feeds to stop times before
    processing the data.
- Minor changes
  - New argument `quiet` to
    [`gtfs2gps()`](https://ipea.github.io/gtfs2gps/dev/reference/gtfs2gps.md)
  - Removed `readr`, `pbapply`, `lwgeom` and `magrittr` from package
    dependencies.

## gtfs2gps v2.0-3

- Minor changes
  - Saving units when using argument `filepath` in
    [`gtfs2gps()`](https://ipea.github.io/gtfs2gps/dev/reference/gtfs2gps.md).

## gtfs2gps v2.0-1

CRAN release: 2022-03-05

- Major changes
  - Imports `gtfstools` package.
- Minor changes
  - Fixing CRAN error and warning related to the vignette.
  - The function
    [`adjust_speed()`](https://ipea.github.io/gtfs2gps/dev/reference/adjust_speed.md)
    now does not change very low speed (1.000000e-12 \[km/h\]) because
    these values indicate a situation of a stopped vehicle. Closed
    [249](https://github.com/ipea/gtfs2gps/issues/249).

## gtfs2gps v2.0-1

CRAN release: 2022-03-05

- Minor changes
  - [`gtfs2gps()`](https://ipea.github.io/gtfs2gps/dev/reference/gtfs2gps.md)
    now prints a message alerting if there are any trips with negative
    speed values in the output.
    [Closes](https://github.com/ipea/gtfs2gps/issues/172)
    [\#172](https://github.com/ipea/gtfs2gps/issues/172).
  - Fixing small bugs in the output of gtfs2gps().

## gtfs2gps v2.0-0

CRAN release: 2022-02-22

- Major changes
  - [`gtfs2gps()`](https://ipea.github.io/gtfs2gps/dev/reference/gtfs2gps.md)
    now creates two points for a stop when arrival and departure exist.
    Speed and travel time are now calculated considering both
    departure\_ and arrival_time columns.
  - The travel statistics in the output table (speed, dist, cumdist,
    cumtime) for a given point are now calculated in relation to the
    previous point. More details in the documentation of the
    [`gtfs2gps()`](https://ipea.github.io/gtfs2gps/dev/reference/gtfs2gps.md)
    function.
  - Names of the output columns of gtfs2gps() were updated
  - New function
    [`adjust_arrival_departure()`](https://ipea.github.io/gtfs2gps/dev/reference/adjust_arrival_departure.md)
    to allow users set a minimum time for dis/embarking times at each
    stop.
  - New function
    [`adjust_speed()`](https://ipea.github.io/gtfs2gps/dev/reference/adjust_speed.md)
    to fix outlier speeds and replace missing speed values with a speed
    set by the user or the average speed of the system. The timestamp
    values are updated accordingly.
  - Fixing several small errors in the output of gtfs2gps(), what breaks
    compatibility with previous versions of the gtfs2gps package.

## gtfs2gps v1.5-4

CRAN release: 2021-09-06

- Major changes
  - Fixed CRAN bugs
  - Fixed small bug that prevented creating departure times correctly

## gtfs2gps v1.5

- Major changes
  - Fixed the update of trip_number attribute. This affects the output
    of
    [`gps_as_sflinestring()`](https://ipea.github.io/gtfs2gps/dev/reference/gps_as_sflinestring.md).
    Closes [\#189](https://github.com/ipea/gtfs2gps/issues/189).
  - Imports the `gtfsio` package, used in the
    [`read_gtfs()`](https://ipea.github.io/gtfs2gps/dev/reference/read_gtfs.md)
    and
    [`write_gtfs()`](https://ipea.github.io/gtfs2gps/dev/reference/write_gtfs.md)
    functions. Closes
    [\#191](https://github.com/ipea/gtfs2gps/issues/191).
  - New parameter `snap_method` added to
    [`gtfs2gps()`](https://ipea.github.io/gtfs2gps/dev/reference/gtfs2gps.md).
- Minor changes
  - Function
    [`filter_single_trip()`](https://ipea.github.io/gtfs2gps/dev/reference/filter_single_trip.md)
    now also filters the `stop_times` table. Closes
    [\#195](https://github.com/ipea/gtfs2gps/issues/195).
  - Change default `spatial_resolution` of
    [`gtfs2gps()`](https://ipea.github.io/gtfs2gps/dev/reference/gtfs2gps.md)
    from 50m to 100m. Closes
    [\#202](https://github.com/ipea/gtfs2gps/issues/202).

## gtfs2gps v1.3-2

CRAN release: 2020-11-05

- Major changes
  - New function to merge GTFS feeds. Closes
    [\#34](https://github.com/ipea/gtfs2gps/issues/34)
  - New pkgdown website. <https://ipea.github.io/gtfs2gps/> . Closes
    [\#146](https://github.com/ipea/gtfs2gps/issues/146)
  - Distance of 1st point of GPS trip now start with distance zero.
    Closes [\#136](https://github.com/ipea/gtfs2gps/issues/136)
- Minor changes
  - changes parallel execution to conform new `future` standards. closes
    [\#55](https://github.com/ipea/gtfs2gps/issues/55)
  - Improve time filter in `filter_day_period`. Closes
    [\#89](https://github.com/ipea/gtfs2gps/issues/89) and 147
  - Improved documentation of `spatial_resolution` parameter. Closes
    [\#116](https://github.com/ipea/gtfs2gps/issues/116)

## gtfs2gps v1.3-0

CRAN release: 2020-09-15

- Major changes
  - Use progress bar from progressr. Closes
    [\#142](https://github.com/ipea/gtfs2gps/issues/142)
  - Handling units of measurement
  - Speeding up some algorithms

## gtfs2gps v1.2-1

CRAN release: 2020-06-12

- Minor changes
  - Allowing to read gtfs files without calendar/agency
  - New verifications to create a better feedback for the user

## gtfs2gps v1.2-0

CRAN release: 2020-05-28

- Major changes
  - Processing mixed detailed and frequency-based GTFS files
  - Small changes in
    [`gps_as_sflinestring()`](https://ipea.github.io/gtfs2gps/dev/reference/gps_as_sflinestring.md)
    due to new GDAL
  - Function to simplify shapes

## gtfs2gps v1.1-0

CRAN release: 2020-04-12

- Major changes
  - New function append_height(), to create height column to GPS data
  - Update related to the newest versions of lwgeom and sf
    ([\#112](https://github.com/ipea/gtfs2gps/issues/112))
  - Replacing `sf_multipoint` by `sf_point` in `gps_as_sf()` to keep all
    the data

## gtfs2gps v1.0-7

CRAN release: 2020-04-01

- Minor changes
  - Removing bugs found by CRAN automatic tests

## gtfs2gps v1.0-5

CRAN release: 2020-03-16

- Launch of **gtfs2gps** v1.0-5 on
  [CRAN](https://CRAN.R-project.org/package=gtfs2gps) on 2020-03-16
