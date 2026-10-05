# Convert GTFS stops to simple feature object

Convert a GTFS stops data loaded using gtfs2gps::read_gtf() into a point
simple feature (sf).

## Usage

``` r
gtfs_stops_as_sf(gtfs, crs = 4326)
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
poa_shapes <- gtfs_shapes_as_sf(poa)
poa_stops <- gtfs_stops_as_sf(poa)
```
