# Read GTFS data into a list of data.tables

Read files of a zipped GTFS feed and load them to memory as a list of
data.tables. It will load the following files: "shapes.txt",
"stop_times.txt", "stops.txt", "trips.txt", "agency.txt",
"calendar.txt", "routes.txt", and "frequencies.txt", with this last four
being optional. If one of the mandatory files does not exit, this
function will stop with an error message.

## Usage

``` r
read_gtfs(gtfszip, quiet = FALSE)
```

## Arguments

- gtfszip:

  A zipped GTFS data.

- quiet:

  A logical. Whether to hide log messages and progress bars. Defaults to
  \`FALSE\`.

## Value

A list of data.tables, where each index represents the respective GTFS
file name.

## Examples

``` r
poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"))
#> Unzipped the following files to /tmp/RtmpvsnyV4/gtfsio:
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
```
