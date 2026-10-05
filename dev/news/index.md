# Changelog

## gtfs2gps (development version)

- Major changes
  - The package now requires R \>= 4.1.0, because it uses the native
    pipe `|>`.
  - Fixed a bug in
    [`write_gtfs()`](https://ipeagit.github.io/gtfs2gps/dev/reference/write_gtfs.md),
    which ignored the `overwrite` argument and silently overwrote an
    existing file. With `overwrite = FALSE` it now raises an error of
    class `gtfs2gps_file_exists_error` if `zipfile` already exists.
  - [`gtfs_shapes_as_sf()`](https://ipeagit.github.io/gtfs2gps/dev/reference/gtfs_shapes_as_sf.md)
    now wraps
    [`gtfstools::convert_shapes_to_sf()`](https://rdrr.io/pkg/gtfstools/man/convert_shapes_to_sf.html).
    The `crs` argument transforms the shapes from WGS84 instead of
    relabelling their coordinates, and must be a valid CRS (`NA` is no
    longer accepted). The input is not modified. The result is a plain
    `sf` object (no longer also a `data.table`) with columns `shape_id`,
    `geometry` and `length`. `shape_id` must be character and
    `shape_pt_sequence` integer, as produced by
    [`read_gtfs()`](https://ipeagit.github.io/gtfs2gps/dev/reference/read_gtfs.md).
  - Fixed two bugs in
    [`gtfs2gps()`](https://ipeagit.github.io/gtfs2gps/dev/reference/gtfs2gps.md)
    for shapes used by several trips:
    - Trips were silently dropped when a shape was shared by more than
      one route; only the first route’s trips were converted (e.g. 170
      of the 348 trips in the bundled Berlin feed). All trips of a shape
      that have a `route_id` are now converted, each with its own
      `route_type`, and `trip_number` is the trip’s index among all
      trips of the shape.
    - Trips with a different stop pattern from the shape’s longest trip
      had their times attached to the wrong stops, and could gain stops
      they do not serve. Stops are now snapped separately for each
      distinct stop pattern on a shape.
- Minor changes
  - [`gtfs2gps()`](https://ipeagit.github.io/gtfs2gps/dev/reference/gtfs2gps.md)
    is faster: speeds and timestamps between stops are now interpolated
    on plain vectors instead of per-segment data.table sub-assignments.
    Output is unchanged.
  - [`write_gtfs()`](https://ipeagit.github.io/gtfs2gps/dev/reference/write_gtfs.md)
    now validates its arguments, and its documentation gives the correct
    default of `quiet` (`FALSE`) and return value (the GTFS data,
    invisibly).
  - New dependency: {cli}, used for the new classed error in
    [`write_gtfs()`](https://ipeagit.github.io/gtfs2gps/dev/reference/write_gtfs.md).
    Existing messages will be migrated to it gradually.
  - Internal code that duplicated {gtfstools} was removed: the frequency
    expansion inside
    [`gtfs2gps()`](https://ipeagit.github.io/gtfs2gps/dev/reference/gtfs2gps.md)
    (unreachable since v2.1-1, when
    [`gtfstools::frequencies_to_stop_times()`](https://rdrr.io/pkg/gtfstools/man/frequencies_to_stop_times.html)
    took over) and the R-level time parser, now
    [`gtfstools::convert_time_to_seconds()`](https://rdrr.io/pkg/gtfstools/man/convert_time_to_seconds.html).
    No output change for well-formed `H:MM:SS` times. In
    [`gtfs2gps()`](https://ipeagit.github.io/gtfs2gps/dev/reference/gtfs2gps.md)
    and
    [`adjust_arrival_departure()`](https://ipeagit.github.io/gtfs2gps/dev/reference/adjust_arrival_departure.md),
    malformed time strings (e.g. `"05:21"`, which used to parse to an
    arbitrary value) are now treated as missing.
  - [`adjust_arrival_departure()`](https://ipeagit.github.io/gtfs2gps/dev/reference/adjust_arrival_departure.md)
    no longer modifies the input GTFS, works when `arrival_time` or
    `departure_time` is absent from `stop_times`, and returns a
    `dt_gtfs` object even for plain-list input.
  - [`filter_valid_stop_times()`](https://ipeagit.github.io/gtfs2gps/dev/reference/filter_valid_stop_times.md)
    now drops any time that is not of the form `H:MM:SS`
    (e.g. `"05:21"`, which used to be kept) and no longer re-formats the
    strings it keeps.
  - {gtfstools} \>= 1.3.0 is now required.

## gtfs2gps v2.1-2

CRAN release: 2024-10-08

- Minor changes
  - puts package back on CRAN
  - remove {magrittr} from Suggests
  - Clarifies in the documentation the default behavior of the parameter
    `ncores`. closes
    [\#271](https://github.com/ipeaGIT/gtfs2gps/issues/271). When
    `parallel = FALSE`, this argument is ignored. When
    `parallel = TRUE`, then by default the function uses all available
    cores minus one.

## gtfs2gps v2.1-1

CRAN release: 2023-04-28

- Major changes
  - Filter functions were removed from the package because gtftools
    alredy implements them
  - Function `gtfs2gps` now uses `parallel = TRUE` by default.
  - Function `gtfs2gps` now uses
    [`gtfstools::frequencies_to_stop_times()`](https://rdrr.io/pkg/gtfstools/man/frequencies_to_stop_times.html)
    to convert. frequency-based GTFS feeds to stop times before
    processing the data.
- Minor changes
  - New argument `quiet` to
    [`gtfs2gps()`](https://ipeagit.github.io/gtfs2gps/dev/reference/gtfs2gps.md)
  - Removed `readr`, `pbapply`, `lwgeom` and `magrittr` from package
    dependencies.

## gtfs2gps v2.0-3

- Minor changes
  - Saving units when using argument `filepath` in
    [`gtfs2gps()`](https://ipeagit.github.io/gtfs2gps/dev/reference/gtfs2gps.md).

## gtfs2gps v2.0-1

CRAN release: 2022-03-05

- Major changes
  - Imports `gtfstools` package.
- Minor changes
  - Fixing CRAN error and warning related to the vignette.
  - The function
    [`adjust_speed()`](https://ipeagit.github.io/gtfs2gps/dev/reference/adjust_speed.md)
    now does not change very low speed (1.000000e-12 \[km/h\]) because
    these values indicate a situation of a stopped vehicle. Closed
    [249](https://github.com/ipeaGIT/gtfs2gps/issues/249).

## gtfs2gps v2.0-1

CRAN release: 2022-03-05

- Minor changes
  - [`gtfs2gps()`](https://ipeagit.github.io/gtfs2gps/dev/reference/gtfs2gps.md)
    now prints a message alerting if there are any trips with negative
    speed values in the output.
    [Closes](https://github.com/ipeaGIT/gtfs2gps/issues/172)
    [\#172](https://github.com/ipeaGIT/gtfs2gps/issues/172).
  - Fixing small bugs in the output of gtfs2gps().

## gtfs2gps v2.0-0

CRAN release: 2022-02-22

- Major changes
  - [`gtfs2gps()`](https://ipeagit.github.io/gtfs2gps/dev/reference/gtfs2gps.md)
    now creates two points for a stop when arrival and departure exist.
    Speed and travel time are now calculated considering both
    departure\_ and arrival_time columns.
  - The travel statistics in the output table (speed, dist, cumdist,
    cumtime) for a given point are now calculated in relation to the
    previous point. More details in the documentation of the
    [`gtfs2gps()`](https://ipeagit.github.io/gtfs2gps/dev/reference/gtfs2gps.md)
    function.
  - Names of the output columns of gtfs2gps() were updated
  - New function
    [`adjust_arrival_departure()`](https://ipeagit.github.io/gtfs2gps/dev/reference/adjust_arrival_departure.md)
    to allow users set a minimum time for dis/embarking times at each
    stop.
  - New function
    [`adjust_speed()`](https://ipeagit.github.io/gtfs2gps/dev/reference/adjust_speed.md)
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
    [`gps_as_sflinestring()`](https://ipeagit.github.io/gtfs2gps/dev/reference/gps_as_sflinestring.md).
    Closes [\#189](https://github.com/ipeaGIT/gtfs2gps/issues/189).
  - Imports the `gtfsio` package, used in the
    [`read_gtfs()`](https://ipeagit.github.io/gtfs2gps/dev/reference/read_gtfs.md)
    and
    [`write_gtfs()`](https://ipeagit.github.io/gtfs2gps/dev/reference/write_gtfs.md)
    functions. Closes
    [\#191](https://github.com/ipeaGIT/gtfs2gps/issues/191).
  - New parameter `snap_method` added to
    [`gtfs2gps()`](https://ipeagit.github.io/gtfs2gps/dev/reference/gtfs2gps.md).
- Minor changes
  - Function
    [`filter_single_trip()`](https://ipeagit.github.io/gtfs2gps/dev/reference/filter_single_trip.md)
    now also filters the `stop_times` table. Closes
    [\#195](https://github.com/ipeaGIT/gtfs2gps/issues/195).
  - Change default `spatial_resolution` of
    [`gtfs2gps()`](https://ipeagit.github.io/gtfs2gps/dev/reference/gtfs2gps.md)
    from 50m to 100m. Closes
    [\#202](https://github.com/ipeaGIT/gtfs2gps/issues/202).

## gtfs2gps v1.3-2

CRAN release: 2020-11-05

- Major changes
  - New function to merge GTFS feeds. Closes
    [\#34](https://github.com/ipeaGIT/gtfs2gps/issues/34)
  - New pkgdown website. <https://ipeagit.github.io/gtfs2gps/> . Closes
    [\#146](https://github.com/ipeaGIT/gtfs2gps/issues/146)
  - Distance of 1st point of GPS trip now start with distance zero.
    Closes [\#136](https://github.com/ipeaGIT/gtfs2gps/issues/136)
- Minor changes
  - changes parallel execution to conform new `future` standards. closes
    [\#55](https://github.com/ipeaGIT/gtfs2gps/issues/55)
  - Improve time filter in `filter_day_period`. Closes
    [\#89](https://github.com/ipeaGIT/gtfs2gps/issues/89) and 147
  - Improved documentation of `spatial_resolution` parameter. Closes
    [\#116](https://github.com/ipeaGIT/gtfs2gps/issues/116)

## gtfs2gps v1.3-0

CRAN release: 2020-09-15

- Major changes
  - Use progress bar from progressr. Closes
    [\#142](https://github.com/ipeaGIT/gtfs2gps/issues/142)
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
    [`gps_as_sflinestring()`](https://ipeagit.github.io/gtfs2gps/dev/reference/gps_as_sflinestring.md)
    due to new GDAL
  - Function to simplify shapes

## gtfs2gps v1.1-0

CRAN release: 2020-04-12

- Major changes
  - New function append_height(), to create height column to GPS data
  - Update related to the newest versions of lwgeom and sf
    ([\#112](https://github.com/ipeaGIT/gtfs2gps/issues/112))
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
