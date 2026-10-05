# Convert GTFS shapes to simple feature object

Convert the shapes of a GTFS data loaded using
[`read_gtfs`](https://ipeagit.github.io/gtfs2gps/dev/reference/read_gtfs.md)
into a LINESTRING simple feature (sf) object, using
[`convert_shapes_to_sf`](https://rdrr.io/pkg/gtfstools/man/convert_shapes_to_sf.html),
and add the length of each shape in kilometres. The input data is not
modified.

## Usage

``` r
gtfs_shapes_as_sf(gtfs, crs = 4326)
```

## Arguments

- gtfs:

  A GTFS data. `shape_id` must be character and `shape_pt_sequence`
  integer, as produced by
  [`read_gtfs`](https://ipeagit.github.io/gtfs2gps/dev/reference/read_gtfs.md).

- crs:

  The coordinate reference system of the output: an EPSG code, a string
  accepted by
  [`st_crs`](https://r-spatial.github.io/sf/reference/st_crs.html), or a
  `crs` object. Shapes are read as WGS84 (EPSG:4326) and transformed to
  `crs`. The default value is 4326 (no transformation). It must be a
  valid CRS: `NA` or an unknown CRS raises an error of class
  `gtfs2gps_crs_error`.

## Value

A simple feature (sf) object with columns `shape_id`, `geometry` and
`length` (km).

## Examples

``` r
poa <- read_gtfs(system.file("extdata/saopaulo.zip", package = "gtfs2gps"))
#> Unzipped the following files to /tmp/RtmptxC49M/gtfsio:
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
poa_sf <- gtfs_shapes_as_sf(poa)
```
