# Filter GTFS trips in order to have one trip per shape_id

Filter a GTFS data by keeping only the first trip of each shape_id,
using
[`gtfstools::filter_by_trip_id()`](https://ipea.github.io/gtfstools/reference/filter_by_trip_id.html).
Trips without a shape_id are dropped. The other tables (stop_times,
frequencies, shapes, routes, stops, calendar, etc.) keep only the rows
used by the remaining trips. The input data is not modified.

## Usage

``` r
filter_single_trip(gtfs_data)
```

## Arguments

- gtfs_data:

  A list of data.tables read using gtfs2gps::read_gtfs().

## Value

A filtered GTFS data.

## Examples

``` r
poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"))
#> Unzipped the following files to /tmp/RtmpK6nZCu/gtfsio:
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
