# Convert GTFS to GPS-like data given a spatial resolution

Convert GTFS data to GPS format by sampling points using a given spatial
resolution. This function creates additional points in order to
guarantee that two points in a same trip will have at most a given
distance, indicated as a spatial resolution. It is possible to use
future package to parallelize the execution (or use argument plan). This
function also uses progressr internally to show progress bars. See the
example below on how to show a progress bar while executing this
function.

## Usage

``` r
gtfs2gps(
  gtfs_data,
  spatial_resolution = 100,
  parallel = TRUE,
  ncores = NULL,
  strategy = NULL,
  filepath = NULL,
  compress = FALSE,
  snap_method = "nearest2",
  continue = FALSE,
  quiet = FALSE
)
```

## Arguments

- gtfs_data:

  A path to a GTFS file to be converted to GPS, or a GTFS data
  represented as a list of data.tables.

- spatial_resolution:

  The spatial resolution in meters. Default is 100m. This function only
  creates points in order to guarantee that the minimum distance between
  two consecutive points will be at most the spatial_resolution. If a
  given shape has two consecutive points with a distance lower than the
  spatial resolution, the algorithm will not remove such points.

- parallel:

  Decides whether the function should run in parallel. Defaults is
  FALSE. When TRUE, it will use all cores available minus one using
  future::plan() with strategy "multisession" internally. Note that it
  is possible to create your own plan before calling gtfs2gps(). In this
  case, do not use this argument.

- ncores:

  Number of cores to be used in parallel execution. When \`parallel =
  FALSE\`, this argument is ignored. When \`parallel = TRUE\`, then by
  default the function uses all available cores minus one.

- strategy:

  This argument is deprecated. Please use argument plan instead or use
  future::plan() directly.

- filepath:

  Output file path. As default, the output is returned when gtfs2gps
  finishes. When this argument is set, each route is saved into a txt
  file within filepath, with the name equals to its id. In this case, no
  output is returned. See argument compress for another option.

- compress:

  Argument that can be used only with filepath. When TRUE, it compresses
  the output files by saving them using rds format. Default value is
  FALSE. Note that compress guarantees that the data saved will be read
  in the same way as it was created in R. If not compress, the txt
  extension requires the data to be converted from ITime to string, and
  therefore they need to manually converted back to ITime to be properly
  handled by gtfs2gps.

- snap_method:

  The method used to snap stops to the route geometry. There are two
  available methods: \`nearest1\` and \`nearest2\`. Defaults to
  \`nearest2\`. See details for more info.

- continue:

  Argument that can be used only with filepath. When TRUE, it skips
  processing the shape identifiers that were already saved into files.
  It is useful to continue processing a GTFS file that was stopped for
  some reason. Default value is FALSE.

- quiet:

  Hide messages while processing the data? Defaults to FALSE.

## Value

A \`data.table\`, where each row represents a GPS point. The following
columns are returned (units of measurement in parenthesis): dist and
cumdist (meters), cumtime (seconds), shape_pt_lon and shape_pt_lat
(degrees), speed (km/h), timestamp (hh:mm:ss).

## Details

After creating geometry points for a given shape id, the \`gtfs2gps()\`
function snaps the stops to the route geometry. Two strategies are
implemented to do this. - The \`nearest2\` method (default) triangulates
the distance between each stop and the two nearest points in the route
geometry to decide which point the stop should be snapped to. If there
is any stop that is further away to the route geometry than
\`spatial_resolution\`, the algorithm recursively doubles the
\`spatial_resolution\` to do the search/snap of all stops. - The
\`nearest1\` method traverses the geometry points computing their
distances to the first stop. Whenever it finds a distance to the stop
smaller than \`spatial_resolution\`, then the stop will be snapped to
such point. The algorithm then applies the same strategy to the next
stop until the vector of stops end.

The \`speed\`, \`cumdist\`, and \`cumtime\` are based on the difference
of distance and time between the current and previous row of the same
trip. It means that the first data point at the first stop of each trip
represens a stationary vehicle. The \`adjust_speed()\` function can be
used to post-process the output to replace eventual \`NA\` values in the
\`speed\` column.

Each stop is presented as two data points for each trip in the output.
The \`timestamp\` value in the first data point represents the time when
the vehicle arrived at that stop (corresponding the \`arrival_time\`
column in the \`stop_times.txt\` file), while the \`timestamp\` in the
second data point represents the time when the vehicle departured from
that stop (corresponding the \`departure_time\` column in the
\`stop_times.txt\` file). The second point considers that the vehicle is
stationary at the stop, immediately before departing.

Some GTFS feeds do not report embark/disembark times (so
\`arrival_time\` and \`departure_time\` are identical at the same stop).
In this case, the user can call the \`adjust_arrival_departure()\`
function to set the minimum time each vehicle will spend at stops to
embark/disembark passengers.

To avoid division by zero, the minimum speed of vehicles in the output
is 1e-12 Km/h, so that vehicles are never completely stopped.

## Examples

``` r
library(gtfs2gps)

gtfs <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps")) |>
  gtfstools::filter_by_shape_id("T2-1") |>
  filter_single_trip()
#> Unzipped the following files to /tmp/RtmpGEQshD/gtfsio:
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
  
poa_gps <- progressr::with_progress(gtfs2gps(gtfs, quiet=TRUE))
#> Warning: UNRELIABLE VALUE: Future (<unnamed-5>) unexpectedly generated random numbers without specifying argument 'seed'. There is a risk that those random numbers are not statistically sound and the overall results might be invalid. To fix this, specify 'seed=TRUE'. This ensures that proper, parallel-safe random numbers are produced. To disable this check, use 'seed=NULL', or set option 'future.rng.onMisuse' to "ignore". [future <unnamed-5> (0acfe8b143d2cc33640a4bfee98b78d9-5); on 0acfe8b143d2cc33640a4bfee98b78d9@runnervmwvtoz<6587>]
```
