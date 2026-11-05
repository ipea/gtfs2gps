# Converts a GPS-like data.table to a LineString Simple Feature (sf) object

Every interval of GPS data points between stops for each trip_id is
converted into a linestring segment. The output assumes constant average
speed between consecutive stops.

## Usage

``` r
gps_as_sflinestring(gps)
```

## Arguments

- gps:

  A GPS data.table created with
  [`gtfs2gps`](https://ipea.github.io/gtfs2gps/dev/reference/gtfs2gps.md),
  or the path of a .txt file written by
  `gtfs2gps(filepath = , compress = FALSE)`.

## Value

A simple feature (sf) object in CRS 4326 with one LineString per
interval between consecutive stops of each trip. Besides columns of
`gps` taken from the segment's first point (such as `shape_id`,
`trip_id` and `trip_number`), it has `from_stop_id` and `to_stop_id`
("-" before the first and after the last stop), `from_timestamp` and
`to_timestamp` (`ITime`), and the `speed` (km/h), `dist` and `cumdist`
(m) and `cumtime` (s) of each segment.

## Examples

``` r
library(gtfs2gps)

poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"))
#> Unzipped the following files to /tmp/RtmphjGwSa/gtfsio:
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
poa_subset <- gtfstools::filter_by_shape_id(poa, c("T2-1", "A141-1")) |>
  filter_single_trip()

poa_gps <- gtfs2gps(poa_subset)
#> ℹ Converting shapes to sf objects
#> Using 2 threads
#> ✔ Converting shapes to sf objects [27ms]
#> 
#> ℹ Processing the data
#> ✔ Processing the data [53ms]
#> 

poa_gps_sf <- gps_as_sflinestring(poa_gps)
```
