# Add a column with height to GPS data

Add a column named height to GPS data using a tif data as reference.

## Usage

``` r
append_height(gps, heightfile)
```

## Arguments

- gps:

  A GPS data created from gtfs2gps().

- heightfile:

  The pathname of a tif file with height data.

## Value

The GPS data with a new column named height.

## Examples

``` r
# \donttest{
fortaleza <- system.file("extdata/fortaleza.zip", package = "gtfs2gps")
srtmfile <- system.file("extdata/fortaleza-srtm.tif", package = "gtfs2gps")

gtfs <- read_gtfs(fortaleza) |>
  gtfstools::filter_by_shape_id("shape836-I") |>
  filter_single_trip()
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

fortaleza_gps <- gtfs2gps(gtfs, spatial_resolution = 500, parallel = FALSE, quiet = TRUE) |>
  append_height(srtmfile)
# }
```
