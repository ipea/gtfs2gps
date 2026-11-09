# Convert GTFS shapes to simple feature object (deprecated)

This function is deprecated and will be removed in a future version. Use
[`gtfstools::get_shapes_geometry()`](https://ipea.github.io/gtfstools/reference/get_shapes_geometry.html)
and, for the length of each shape,
[`gtfstools::get_shape_length()`](https://ipea.github.io/gtfstools/reference/get_shape_length.html)
instead.

Convert the shapes of a GTFS data loaded using
[`read_gtfs`](https://ipea.github.io/gtfs2gps/dev/reference/read_gtfs.md)
into a LINESTRING simple feature (sf) object, using
[`get_shapes_geometry`](https://ipea.github.io/gtfstools/reference/get_shapes_geometry.html),
and add the length of each shape in kilometres, using
[`get_shape_length`](https://ipea.github.io/gtfstools/reference/get_shape_length.html).
The input data is not modified.

## Usage

``` r
gtfs_shapes_as_sf(gtfs, crs = 4326)
```

## Arguments

- gtfs:

  A GTFS data. `shape_id` must be character and `shape_pt_sequence`
  integer, as produced by
  [`read_gtfs`](https://ipea.github.io/gtfs2gps/dev/reference/read_gtfs.md).

- crs:

  The coordinate reference system of the output: an EPSG code, a string
  accepted by
  [`st_crs`](https://r-spatial.github.io/sf/reference/st_crs.html), or a
  `crs` object. Shapes are read as WGS84 (EPSG:4326) and transformed to
  `crs`. The default value is 4326 (no transformation). Other inputs
  (e.g. `NA`) raise an error, and an empty or unknown CRS raises an
  error of class `gtfs2gps_crs_error`.

## Value

A simple feature (sf) object with columns `shape_id`, `geometry` and
`length` (km). The length is computed from the WGS84 points of each
shape, whatever `crs` is.

## Examples

``` r
sp <- read_gtfs(system.file("extdata/saopaulo.zip", package = "gtfs2gps"))
#> Unzipped the following files to /tmp/RtmpkG8Usr/gtfsio:
#>   * agency.txt
#>   * calendar.txt
#>   * frequencies.txt
#>   * routes.txt
#>   * shapes.txt
#>   * stop_times.txt
#>   * stops.txt
#>   * trips.txt
#> Reading agency
#> Reading calendar
#> Reading frequencies
#> Reading routes
#> Reading shapes
#> Reading stop_times
#> Reading stops
#> Reading trips
sp_sf <- suppressWarnings(gtfs_shapes_as_sf(sp))
```
