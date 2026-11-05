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

  The coordinate reference system of the output, as accepted by
  [`st_crs`](https://r-spatial.github.io/sf/reference/st_crs.html).
  Points are read as WGS84 (EPSG:4326) and transformed to `crs`. The
  default value is 4326 (no transformation).

## Value

A simple feature (sf) object with point data.

## Examples

``` r
library(gtfs2gps)

fortaleza <- read_gtfs(system.file("extdata/fortaleza.zip", package = "gtfs2gps"))
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
srtmfile <- system.file("extdata/fortaleza-srtm.tif", package="gtfs2gps")

subset <- fortaleza |>
  gtfstools::filter_by_weekday(c("monday", "wednesday")) |>
  filter_single_trip() |>
  gtfstools::filter_by_shape_id("shape806-I")

for_gps <- gtfs2gps(subset)
#> ℹ Converting shapes to sf objects
#> Using 2 threads
#> ✔ Converting shapes to sf objects [197ms]
#> 
#> ℹ Processing the data
#> ✔ Processing the data [48ms]
#> 
for_gps_sf_points <- gps_as_sfpoints(for_gps)
```
