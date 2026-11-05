# Adjust the arrival and departure times of a GTFS data (deprecated)

This function is deprecated and will be removed in a future version; it
warns once per session. Its job has moved to gtfstools: use
[`gtfstools::set_dwell_time()`](https://ipea.github.io/gtfstools/reference/set_dwell_time.html)
or
[`gtfstools::set_min_dwell_time()`](https://ipea.github.io/gtfstools/reference/set_min_dwell_time.html)
to edit and fix GTFS feeds before converting them. Unlike this function,
`set_min_dwell_time()` keeps arrivals, delays the departure and the
later times of the trip, and leaves each trip's first and last timed
stops unchanged (`set_dwell_time()` sets them too); neither fills blank
times.

Some GTFS.zip data have issues related to arrival and departure time on
stops. This function makes sure the GTFS has dis/embarking times at each
stop. For each stop time row, this function applies the following steps:

1.  If there is `arrival_time` but no `departure_time`, it creates a
    departure_time column by summing the arrival plus a pre-defined
    `min_lag`.

2.  If there is `departure_time` but no `arrival_time`, it creates an
    arrival_time column by subtracting a pre-defined `min_lag` from the
    departure.

3.  If there is an `arrival_time` and a `departure_time` but their
    difference is smaller than `min_lag`, it reduces the `arrival_time`
    and increases `departure_time` so that the difference will be
    exactly `min_lag`. Odd differences give the extra second to the
    departure.

Arrivals before 00:00:00 are set to 00:00:00 and the departure moved to
keep `min_lag`. Times are not kept increasing across consecutive stops.

The input GTFS data is not modified.

## Usage

``` r
adjust_arrival_departure(gtfs_data, min_lag = 20)
```

## Arguments

- gtfs_data:

  A GTFS data created with
  [`read_gtfs`](https://ipea.github.io/gtfs2gps/dev/reference/read_gtfs.md).

- min_lag:

  Numeric. Minimum waiting time when a vehicle arrives at a stop. It can
  be a numeric or a units value that can be converted to seconds,
  rounded to whole seconds. Default is 20s.

## Value

A GTFS with adjusted `arrival_time` and `departure_time` on data.table
`stop_times`. Stops with neither time come back with empty strings
(`""`), which GTFS allows for stops that are not timepoints.

## Examples

``` r
poa <- read_gtfs(system.file("extdata/poa.zip", package="gtfs2gps"))
#> Unzipped the following files to /tmp/Rtmp7N1hWT/gtfsio:
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

poa <- adjust_arrival_departure(poa)
#> Warning: `adjust_arrival_departure()` is deprecated and will be removed in a future
#> version.
#> ℹ Its job has moved to gtfstools: use `gtfstools::set_dwell_time()` or
#>   `gtfstools::set_min_dwell_time()` to edit and fix GTFS feeds.
#> This warning is displayed once per session.
```
