# Adjust the arrival and departure times of a GTFS data

Some GTFS.zip data have issues related to arrival and departure time on
stops. This function makes sure the GTFS has dis/embarking times at each
stop. For each stop time row, this function applies the following steps:

1\. If there is \`arrival_time\` but no \`departure_time\`, it creates a
departure_time column by summing the arrival plus a pre-defined
\`min_lag\`.

2\. If there is \`departure_time\` but no \`arrival_time\`, it creates
an arrival_time column by subtracting a pre-defined \`min_lag\` from the
departure.

3\. If there is an \`arrival_time\` and a \`departure_time\` but their
difference is smaller than \`min_lag\`, it reduces the \`arrival_time\`
and increases \`departure_time\` so that the difference will be exactly
\`min_lag\`.

The input GTFS data is not modified.

## Usage

``` r
adjust_arrival_departure(gtfs_data, min_lag = 20)
```

## Arguments

- gtfs_data:

  A GTFS data created with
  [`read_gtfs`](https://ipeagit.github.io/gtfs2gps/reference/read_gtfs.md).

- min_lag:

  Numeric. Minimum waiting time when a vehicle arrives at a stop. It can
  be a numeric or a units value that can be converted to seconds.
  Default is 20s.

## Value

A GTFS with adjusted \`arrival_time\` and \`departure_time\` on
data.table \`stop_times\`.

## Examples

``` r
poa <- read_gtfs(system.file("extdata/poa.zip", package="gtfs2gps"))
#> Unzipped the following files to /tmp/RtmpA2JNhW/gtfsio:
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

poa <- adjust_arrival_departure(poa)
```
