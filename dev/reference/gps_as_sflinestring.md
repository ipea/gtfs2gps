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
poa_subset <- gtfstools::filter_by_shape_id(poa, c("T2-1", "A141-1")) |>
  filter_single_trip()

poa_gps <- gtfs2gps(poa_subset)
#> Converting shapes to sf objects
#> Using 3 CPU cores
#> Processing the data
#> Warning: UNRELIABLE VALUE: Future (<unnamed-2>) unexpectedly generated random numbers without specifying argument 'seed'. There is a risk that those random numbers are not statistically sound and the overall results might be invalid. To fix this, specify 'seed=TRUE'. This ensures that proper, parallel-safe random numbers are produced. To disable this check, use 'seed=NULL', or set option 'future.rng.onMisuse' to "ignore". [future <unnamed-2> (8cf93210de46dee6cd3f3c8db4df4611-2); on 8cf93210de46dee6cd3f3c8db4df4611@runnervma94yk<6835>]
#> Warning: UNRELIABLE VALUE: Future (<unnamed-3>) unexpectedly generated random numbers without specifying argument 'seed'. There is a risk that those random numbers are not statistically sound and the overall results might be invalid. To fix this, specify 'seed=TRUE'. This ensures that proper, parallel-safe random numbers are produced. To disable this check, use 'seed=NULL', or set option 'future.rng.onMisuse' to "ignore". [future <unnamed-3> (8cf93210de46dee6cd3f3c8db4df4611-3); on 8cf93210de46dee6cd3f3c8db4df4611@runnervma94yk<6835>]
#> Some 'speed' values are NA in the returned data.

poa_gps_sf <- gps_as_sflinestring(poa_gps)
```
