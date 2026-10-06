# Filter GTFS trips in order to have one trip per shape_id

Filter a GTFS data by keeping only one trip per shape_id. It also
removes the unnecessary routes and stop_times accordingly.

## Usage

``` r
filter_single_trip(gtfs_data)
```

## Arguments

- gtfs_data:

  A list of data.tables read using gtfs2gps::reag_gtfs().

## Value

A filtered GTFS data.

## Examples

``` r
poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"))
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

subset <- filter_single_trip(poa)
```
