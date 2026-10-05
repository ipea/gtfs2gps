# Filter GTFS data using valid stop times

Filter a GTFS data read using gtfs2gps::read_gtfs(). It removes
stop_times with NA values in arrival_time, departure_time, and
arrival_time_hms. It also filters stops and routes accordingly.

## Usage

``` r
filter_valid_stop_times(gtfs_data)
```

## Arguments

- gtfs_data:

  A list of data.tables read using gtfs2gps::reag_gtfs().

## Value

A filtered GTFS data.

## Examples

``` r
poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps"))
#> Unzipped the following files to /tmp/RtmpjnlsdY/gtfsio:
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

subset <- filter_valid_stop_times(poa)
```
