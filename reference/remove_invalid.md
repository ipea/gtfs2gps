# Remove invalid objects from GTFS data

Remove all objects from GTFS data that are not used in all relations
that they are required to be. That is, agency-routes relation
(agency_id), routes-trips relation (route_id), trips-shapes relation
(shape_id), trips-frequencies relation (trip_id), trips-stop_times
relation (trip_id), stop_times-stops relation (stop_id), and
trips-calendar relation (service_id), recursively, until GTFS data does
not reduce its size anymore. For example, if one agency_id belongs to
routes but not to agency will be removed. This might cause one cascade
removal of objects in other relations that originally did not have any
inconsistency.

## Usage

``` r
remove_invalid(gtfs_data, only_essential = TRUE, prompt_invalid = FALSE)
```

## Arguments

- gtfs_data:

  A list of data.tables read using gtfs2gps::reag_gtfs().

- only_essential:

  Remove only the essential files? The essential files are all but
  agency, calendar, and routes. Default is TRUE, which means that
  agency-routes, routes-trips, and trips-calendar relations will not be
  processed as restrictions to remove objects.

- prompt_invalid:

  Show the invalid objects. Default is FALSE.

## Value

A subset of the input GTFS data.

## Examples

``` r
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
object.size(poa)
#> 1173232 bytes
subset <- remove_invalid(poa)
object.size(subset)
#> 1173232 bytes
```
