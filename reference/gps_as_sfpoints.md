# Convert GPS-like data.table to a Simple Feature points object

Convert a GPS data stored in a data.table into Simple Feature points.

## Usage

``` r
gps_as_sfpoints(gps, crs = 4326)
```

## Arguments

- gps:

  A data.table with timestamp data.

- crs:

  A Coordinate Reference System. The default value is 4326 (latlong
  WGS84).

## Value

A simple feature (sf) object with point data.

## Examples

``` r
library(gtfs2gps)

fortaleza <- read_gtfs(system.file("extdata/fortaleza.zip", package = "gtfs2gps"))
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
srtmfile <- system.file("extdata/fortaleza-srtm.tif", package="gtfs2gps")

subset <- fortaleza |>
  gtfstools::filter_by_weekday(c("monday", "wednesday")) |>
  filter_single_trip() |>
  gtfstools::filter_by_shape_id("shape806-I")

for_gps <- gtfs2gps(subset)
#> Converting shapes to sf objects
#> Using 3 CPU cores
#> Processing the data
#> Warning: UNRELIABLE VALUE: Future (<unnamed-4>) unexpectedly generated random numbers without specifying argument 'seed'. There is a risk that those random numbers are not statistically sound and the overall results might be invalid. To fix this, specify 'seed=TRUE'. This ensures that proper, parallel-safe random numbers are produced. To disable this check, use 'seed=NULL', or set option 'future.rng.onMisuse' to "ignore". [future <unnamed-4> (6fe075cbaa31ef672c811b9ff5e72b46-4); on 6fe075cbaa31ef672c811b9ff5e72b46@runnervma94yk<6708>]
for_gps_sf_points <- gps_as_sfpoints(for_gps)
```
