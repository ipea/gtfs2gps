# Changelog

## gtfs2gps v3.0-0

- Breaking changes
  - Parallelization:
    [`gtfs2gps()`](https://ipea.github.io/gtfs2gps/dev/reference/gtfs2gps.md)
    no longer uses {future} workers or `future::plan()`. The compiled
    step runs in `ncores` threads (OpenMP): the default is 2 and
    `ncores = Inf` uses all threads
    ([`data.table::getDTthreads()`](https://rdrr.io/pkg/data.table/man/openmp-utils.html)).
    `parallel` and `strategy` are deprecated and ignored: use
    `ncores = 1` to run sequentially. This also fixes the “globals
    exceed the maximum allowed size” error
    ([\#277](https://github.com/ipea/gtfs2gps/issues/277)).
  - Stops are located with
    [`gtfstools::interpolate_shape_dist_traveled()`](https://ipea.github.io/gtfstools/reference/interpolate_shape_dist_traveled.html),
    in `stop_sequence` order, then placed at the nearest generated point
    of the shape. Stop placement no longer uses a search radius based on
    `spatial_resolution`, so stop patterns are no longer dropped because
    a stop is far from the shape. `dist`, `cumdist` and `speed` are
    about 0.11% smaller (spherical distances). snap_method is deprecated
    and ignored.
  - Output of
    [`gtfs2gps()`](https://ipea.github.io/gtfs2gps/dev/reference/gtfs2gps.md):
    each trip runs from its first to its last timed stop (`cumdist`
    starts at 0; [\#260](https://github.com/ipea/gtfs2gps/issues/260));
    `speed`, `dist`, `cumdist` and `cumtime` are rounded to 3 decimals;
    timestamps wrap at midnight (use `cumtime` for elapsed time);
    `trip_number` counts all trips of a shape.
  - [`filter_single_trip()`](https://ipea.github.io/gtfs2gps/dev/reference/filter_single_trip.md)
    requires a GTFS object and also filters the other tables;
  - Deprecated:
    [`gtfs_shapes_as_sf()`](https://ipea.github.io/gtfs2gps/dev/reference/gtfs_shapes_as_sf.md),
    [`gtfs_stops_as_sf()`](https://ipea.github.io/gtfs2gps/dev/reference/gtfs_stops_as_sf.md),
    [`remove_invalid()`](https://ipea.github.io/gtfs2gps/dev/reference/remove_invalid.md)
    and
    [`filter_valid_stop_times()`](https://ipea.github.io/gtfs2gps/dev/reference/filter_valid_stop_times.md),
    which warn on every call, and
    [`adjust_arrival_departure()`](https://ipea.github.io/gtfs2gps/dev/reference/adjust_arrival_departure.md)
    and
    [`adjust_speed()`](https://ipea.github.io/gtfs2gps/dev/reference/adjust_speed.md),
    which warn once per session. Use the {gtfstools} equivalents named
    in their warnings: we strongly recommend fixing and editing GTFS
    data with {gtfstools} before processing them with gtfs2gps.
- Major changes
  - [`gtfs2gps()`](https://ipea.github.io/gtfs2gps/dev/reference/gtfs2gps.md)
    is much faster and uses less memory: compared with v2.1-4, about 9×
    faster on the poa feed, 500× on São Paulo, and 1,000× on a full
    Fortaleza feed (13M points: 95 min → 6 s). All shapes are converted
    in one pass in C++ ({cpp11} replaces {Rcpp}).
  - Fixed shapes shared by several routes or stop patterns: all their
    trips are converted, with times attached to the right stops
    (e.g. 348 instead of 170 trips in the Berlin feed).
  - Requires gtfstools \>= 2.0.1
- Minor changes
  - [`gtfs2gps()`](https://ipea.github.io/gtfs2gps/dev/reference/gtfs2gps.md)
    drops duplicated rows and unused ids, ignores trips with an `NA`
    `trip_id`, and converts a `trip_id` listed under two shapes once.
  - Fixed `NaN` `cumtime` after a stop with a departure but no arrival
    time; `continue = TRUE, compress = TRUE` not skipping shapes already
    saved; and `filepath` output for `shape_id`s that aren’t valid file
    names (now `%XX`-encoded).
  - [`read_gtfs()`](https://ipea.github.io/gtfs2gps/dev/reference/read_gtfs.md)
    keeps all `routes.txt` columns and reads feeds without `agency_id`
    or `route_short_name`;
    [`write_gtfs()`](https://ipea.github.io/gtfs2gps/dev/reference/write_gtfs.md)
    gains `compression_level`;
    [`adjust_arrival_departure()`](https://ipea.github.io/gtfs2gps/dev/reference/adjust_arrival_departure.md)
    no longer modifies its input or writes negative times.
  - Messages, warnings and errors use {cli}, most with a class; failed
    shapes are reported in a `gtfs2gps_shape_error` warning. Loading the
    package no longer changes data.table’s options or threads.
  - Dependencies: adds {cli} and {rlang}; drops {furrr}, {future},
    {parallelly}, {progressr} and {Rcpp}.
  - No departure is created at a frequency’s `end_time`, and malformed
    times `NA` with a warning.
  - [`gtfs2gps()`](https://ipea.github.io/gtfs2gps/dev/reference/gtfs2gps.md)
    raises classed errors instead of returning `NULL` when nothing can
    be converted, and when `routes.txt` is missing or the output exceeds
    2.1 billion rows.
  - [`gps_as_sfpoints()`](https://ipea.github.io/gtfs2gps/dev/reference/gps_as_sfpoints.md)
    no longer accepts `crs = NA`
  - [`write_gtfs()`](https://ipea.github.io/gtfs2gps/dev/reference/write_gtfs.md)
    errors when `overwrite = FALSE` and the file exists
  - `spatial_resolution` must be at least 1 metre.

## gtfs2gps v2.1-4

CRAN release: 2026-02-02

- Minor changes
  - `ncores = NULL` uses `parallelly::availableCores(omit = 1)`, and
    {parallelly} was added to Imports.
  - Requires R \>= 4.1.0.
  - The startup message no longer mentions the removed filter functions.
  - Test fix for testthat 3.3.0.

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

## gtfs2gps v2.1-0

CRAN release: 2022-08-16

- Major changes
  - Imports `gtfstools` package.
- Minor changes
  - The function
    [`adjust_speed()`](https://ipea.github.io/gtfs2gps/dev/reference/adjust_speed.md)
    now does not change very low speed (1.000000e-12 \[km/h\]) because
    these values indicate a situation of a stopped vehicle. Closed
    [249](https://github.com/ipea/gtfs2gps/issues/249).

## gtfs2gps v2.0-3

- Minor changes
  - Saving units when using argument `filepath` in
    [`gtfs2gps()`](https://ipea.github.io/gtfs2gps/dev/reference/gtfs2gps.md).

## gtfs2gps v2.0-2

CRAN release: 2022-03-10

- Minor changes
  - Fixing CRAN error and warning related to the vignette.
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
