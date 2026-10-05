# Filter GTFS data using valid stop times

Filter a GTFS data read using gtfs2gps::read_gtfs(). It removes
stop_times whose arrival_time or departure_time is missing or is not a
well-formed "H:MM:SS" time string (hours may exceed 24). It also filters
stops and routes accordingly. The input data is not modified.

## Usage

``` r
filter_valid_stop_times(gtfs_data)
```

## Arguments

- gtfs_data:

  A list of data.tables read using gtfs2gps::read_gtfs().

## Value

A filtered GTFS data.

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

subset <- filter_valid_stop_times(poa)
```
