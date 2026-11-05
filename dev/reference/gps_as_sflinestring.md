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

  A data.table with timestamp data.

## Value

A simple feature (sf) object with LineString data.

## Examples

``` r
library(gtfs2gps)

poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"))
#> Unzipped the following files to /tmp/Rtmpt4vnV3/gtfsio:
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
#> ✔ Converting shapes to sf objects [21ms]
#> 
#> ℹ Processing the data
#> Some speed values are NA in the returned data.
#> ✔ Processing the data [57ms]
#> 

poa_gps_sf <- gps_as_sflinestring(poa_gps)
```
