# Convert GTFS to GPS-like data given a spatial resolution

Convert GTFS data to GPS format by sampling points using a given spatial
resolution. This function creates additional points in order to
guarantee that two points in a same trip will have at most a given
distance, indicated as a spatial resolution.

Stops without times are placed along the shape at constant speed between
the timed stops.
[`fix_gtfs`](https://ipea.github.io/gtfstools/reference/fix_gtfs.html)
can clean a feed before converting it (e.g. duplicated rows and unused
ids), but the stop times it interpolates may give spiky or infinite
speeds here.

## Usage

``` r
gtfs2gps(
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
)
```

## Arguments

- gtfs_data:

  A path to a GTFS file to be converted to GPS, or a GTFS data
  represented as a list of data.tables.

- spatial_resolution:

  The spatial resolution in meters: a number of at least 1, or a `units`
  length. Default is 100m. This function only creates points in order to
  guarantee that consecutive points are at most `spatial_resolution`
  metres apart. If a given shape has two consecutive points with a
  distance lower than the spatial resolution, the algorithm will not
  remove such points.

- parallel:

  This argument is deprecated and ignored. Please use argument ncores
  instead.

- ncores:

  Number of threads used. Defaults to 2. If `Inf`, it uses all threads
  available, as given by
  [`data.table::getDTthreads()`](https://rdrr.io/pkg/data.table/man/openmp-utils.html).

- strategy:

  This argument is deprecated and ignored. Please use argument ncores
  instead.

- filepath:

  Output file path. As default, the output is returned when gtfs2gps
  finishes. When this argument is set, each shape is saved into a txt
  file within filepath, named after its `shape_id`. Characters that
  can't be in a file name on some systems (such as `/`, `:` or `*`) and
  `%` are written as `%XX`, their hexadecimal code, so
  [`utils::URLdecode()`](https://rdrr.io/r/utils/URLencode.html) gives
  the id back (e.g. `"a/b"` is saved as `a%2Fb.txt`). In this case, no
  output is returned. See argument compress for another option.

- compress:

  Argument that can be used only with filepath. When `TRUE`, it
  compresses the output files by saving them using `.rds` format.
  Default value is `FALSE`. Note that compress guarantees that the data
  saved will be read in the same way as it was created in R. If not
  compress, the txt extension requires the data to be converted from
  ITime to string, and therefore they need to be manually converted back
  to ITime to be properly handled by gtfs2gps.

- snap_method:

  This argument is deprecated and ignored. Stops are now located along
  the shapes with
  [`gtfstools::interpolate_shape_dist_traveled()`](https://ipea.github.io/gtfstools/reference/interpolate_shape_dist_traveled.html)
  (see details).

- continue:

  Argument that can be used only with filepath. When TRUE, it skips
  processing the shape identifiers that were already saved into files.
  It is useful to continue processing a GTFS file that was stopped for
  some reason. Default value is `FALSE`.

- quiet:

  Hide messages while processing the data. Defaults to `FALSE`.

## Value

A `data.table`, where each row represents a GPS point. The following
columns are returned (units of measurement in parenthesis): dist and
cumdist (meters), cumtime (seconds), shape_pt_lon and shape_pt_lat
(degrees), speed (km/h), timestamp
([`data.table::ITime`](https://rdrr.io/pkg/data.table/man/IDateTime.html),
wrapped at midnight). Speed, dist, cumdist and cumtime are rounded to 3
decimal places (also when written to filepath), except speeds closer to
zero than that, which keep their value (such as the 1e-12 km/h of
stops). With `filepath`, each shape is written to a file and `NULL` is
returned.

## Details

Before converting, the feed is cleaned with
[`gtfstools::remove_duplicates()`](https://ipea.github.io/gtfstools/reference/remove_duplicates.html)
and
[`gtfstools::remove_unused_ids()`](https://ipea.github.io/gtfstools/reference/remove_unused_ids.html),
and trips with an `NA` `trip_id` are dropped. Errors and warnings raised
by the package have classes starting with `gtfs2gps_` (e.g.
`gtfs2gps_nothing_converted_error`), and deprecation warnings with
`deprecated_`, so they can be caught.

After creating geometry points for a given shape id, the `gtfs2gps()`
function snaps the stops to the route geometry. The stops of each trip
are located along the shape with
[`gtfstools::interpolate_shape_dist_traveled()`](https://ipea.github.io/gtfstools/reference/interpolate_shape_dist_traveled.html),
which projects each stop onto the shape keeping the stops in their
`stop_sequence` order, so that loops and shapes that pass by the same
place more than once are handled. Each stop is then snapped to the
nearest point of the shape in high resolution, moved forward when needed
so that each stop has a point of its own. Distances are great-circle
distances on the sphere used by the s2 and sf packages, with a radius of
6,371,010 m.

Each trip runs from its first to its last stop with a departure time:
shape points (and stops without times) before the first one and after
the last one have no time to be interpolated from, and are not returned.
The `speed`, `cumdist`, and `cumtime` are based on the difference of
distance and time between the current and previous row of the same trip.
It means that the first data point of each trip, at its first stop,
represents a stationary vehicle, with `dist`, `cumdist` and `cumtime`
equal to zero: `cumdist` is the distance travelled from the first stop.
The
[`adjust_speed()`](https://ipea.github.io/gtfs2gps/dev/reference/adjust_speed.md)
function can be used to post-process the output to replace speeds
outside a valid range, or eventual `NA` values (such as two stops at the
same place and time).

Each stop is presented as two data points for each trip in the output.
The `timestamp` value in the first data point represents the time when
the vehicle arrived at that stop (corresponding the `arrival_time`
column in the `stop_times.txt` file), while the `timestamp` in the
second data point represents the time when the vehicle departed from
that stop (corresponding the `departure_time` column in the
`stop_times.txt` file). The second point considers that the vehicle is
stationary at the stop, immediately before departing.

Some GTFS feeds do not report embark/disembark times (so `arrival_time`
and `departure_time` are identical at the same stop). In this case, the
user can call the
[`adjust_arrival_departure()`](https://ipea.github.io/gtfs2gps/dev/reference/adjust_arrival_departure.md)
function to set the minimum time each vehicle will spend at stops to
embark/disembark passengers.

To avoid division by zero, the minimum speed of vehicles in the output
is 1e-12 km/h, so that vehicles are never completely stopped.

## Examples

``` r
library(gtfs2gps)

gtfs <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps")) |>
  gtfstools::filter_by_shape_id("T2-1") |>
  filter_single_trip()
#> Unzipped the following files to /tmp/Rtmpynnshe/gtfsio:
#>   * agency.txt
#>   * calendar.txt
#>   * routes.txt
#>   * shapes.txt
#>   * stop_times.txt
#>   * stops.txt
#>   * trips.txt
#> Reading agency
#> Reading calendar
#> Reading routes
#> Reading shapes
#> Reading stop_times
#> Reading stops
#> Reading trips

poa_gps <- gtfs2gps(gtfs, quiet = TRUE)
```
