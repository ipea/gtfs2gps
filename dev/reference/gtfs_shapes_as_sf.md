# Convert GTFS shapes to simple feature object

Convert a GTFS shapes data loaded using gtfs2gps::read_gtf() into a line
simple feature (sf).

## Usage

``` r
gtfs_shapes_as_sf(gtfs, crs = 4326)
```

## Arguments

- gtfs:

  A GTFS data.

- crs:

  The coordinate reference system represented as an EPSG code. The
  default value is 4326 (latlong WGS84)

## Value

A simple feature (sf) object.

## Examples

``` r
poa <- read_gtfs(system.file("extdata/saopaulo.zip", package = "gtfs2gps"))
#> Unzipped the following files to /tmp/RtmpjnlsdY/gtfsio:
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
