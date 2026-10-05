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
poa_subset <- gtfstools::filter_by_shape_id(poa, c("T2-1", "A141-1")) |>
  filter_single_trip()

poa_gps <- gtfs2gps(poa_subset)
#> Converting shapes to sf objects
#> Using 3 CPU cores
#> Processing the data
#> Warning: UNRELIABLE VALUE: Future (<unnamed-2>) unexpectedly generated random numbers without specifying argument 'seed'. There is a risk that those random numbers are not statistically sound and the overall results might be invalid. To fix this, specify 'seed=TRUE'. This ensures that proper, parallel-safe random numbers are produced. To disable this check, use 'seed=NULL', or set option 'future.rng.onMisuse' to "ignore". [future <unnamed-2> (6fe075cbaa31ef672c811b9ff5e72b46-2); on 6fe075cbaa31ef672c811b9ff5e72b46@runnervma94yk<6708>]
#> Warning: UNRELIABLE VALUE: Future (<unnamed-3>) unexpectedly generated random numbers without specifying argument 'seed'. There is a risk that those random numbers are not statistically sound and the overall results might be invalid. To fix this, specify 'seed=TRUE'. This ensures that proper, parallel-safe random numbers are produced. To disable this check, use 'seed=NULL', or set option 'future.rng.onMisuse' to "ignore". [future <unnamed-3> (6fe075cbaa31ef672c811b9ff5e72b46-3); on 6fe075cbaa31ef672c811b9ff5e72b46@runnervma94yk<6708>]
#> Some 'speed' values are NA in the returned data.

poa_gps_sf <- gps_as_sflinestring(poa_gps)
```
