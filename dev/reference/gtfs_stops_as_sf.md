# Convert GTFS stops to simple feature object (deprecated)

This function is deprecated and will be removed in a future version. Use
[`gtfstools::get_stops_geometry()`](https://ipea.github.io/gtfstools/reference/get_stops_geometry.html)
instead.

Convert the stops of a GTFS data loaded using
[`read_gtfs`](https://ipea.github.io/gtfs2gps/dev/reference/read_gtfs.md)
into a POINT simple feature (sf) object, using
[`get_stops_geometry`](https://ipea.github.io/gtfstools/reference/get_stops_geometry.html).
The input data is not modified.

## Usage

``` r
gtfs_stops_as_sf(gtfs, crs = 4326)
```

## Arguments

- gtfs:

  A GTFS data. `stop_id` must be character and `stop_lon` and `stop_lat`
  numeric, as produced by
  [`read_gtfs`](https://ipea.github.io/gtfs2gps/dev/reference/read_gtfs.md).

- crs:

  The coordinate reference system of the output: an EPSG code, a string
  accepted by
  [`st_crs`](https://r-spatial.github.io/sf/reference/st_crs.html), or a
  `crs` object. Stops are read as WGS84 (EPSG:4326) and transformed to
  `crs`. The default value is 4326 (no transformation). Other inputs
  (e.g. `NA`) raise an error, and an empty or unknown CRS raises an
  error of class `gtfs2gps_crs_error`.

## Value

A simple feature (sf) object.

## Examples

``` r
poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"))
#> Unzipped the following files to /tmp/RtmpNavyfO/gtfsio:
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
poa_stops <- suppressWarnings(gtfs_stops_as_sf(poa))
```
