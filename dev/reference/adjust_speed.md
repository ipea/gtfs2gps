# Adjust the speeds of a gps-like table created with [`gtfs2gps`](https://ipea.github.io/gtfs2gps/dev/reference/gtfs2gps.md) (deprecated)

This function is deprecated and will be removed in a future version; it
warns once per session. It edits the GPS-like output of
[`gtfs2gps()`](https://ipea.github.io/gtfs2gps/dev/reference/gtfs2gps.md).
We strongly recommend using our sister package gtfstools to fix and edit
GTFS data before processing them with gtfs2gps, for example with
[`gtfstools::set_max_speed()`](https://ipea.github.io/gtfstools/reference/set_max_speed.html)
and `gtfstools::set_min_speed()` (the latter in the development version
of gtfstools). Unlike this function, they work on the GTFS before
conversion, and do not replace missing speeds in the GPS output.

Some GTFS.zip data sets might have quality issues, for example by
assuming that a trip speed is unreasonably high (e.g. an urban bus
running over 100 km/h), or in other cases the `timestamp` information
might be missing for some route segments. This can lead a gps-like table
to have `NA` or unrealistic `speed` and `timestamp` values.

This function allows the user to adjust the speed of trips and updates
`timestamp` values accordingly. The user can adjust the problematic
speeds by either setting a custom constant value, or by considering the
distance-weighted mean of the valid speeds (Default). The columns
`timestamp` and `cumtime` are updated accordingly.

Each trip keeps the timestamp of its first timed point, and dwell times
at stops are kept, so stop timestamps don't change when every speed is
within range; segments whose speeds are replaced are re-timed. Trips
without any timestamp keep `NA` timestamps. Timestamps wrap at 24:00:00.
`gps_data` must be ordered as
[`gtfs2gps`](https://ipea.github.io/gtfs2gps/dev/reference/gtfs2gps.md)
returns it.

## Usage

``` r
adjust_speed(
  gps_data,
  min_speed = 2,
  max_speed = 80,
  new_speed = NULL,
  clone = TRUE
)
```

## Arguments

- gps_data:

  A GPS-like data.table created with
  [`gtfs2gps`](https://ipea.github.io/gtfs2gps/dev/reference/gtfs2gps.md).

- min_speed:

  Minimum speed to be considered as valid. It can be a numeric (in km/h)
  or a units value able to be converted to km/h. Values below minimum
  speed will be adjusted. Defaults to 2 km/h; must be a single number,
  not negative. Outside stops, speeds that round to 0 km/h at 3 decimals
  are also adjusted, as they would take too long to cover any distance.

- max_speed:

  Maximum speed to be considered as valid. It can be a numeric (in km/h)
  or a units value able to be converted to km/h. Values above maximum
  speed will be adjusted. Defaults to 80 km/h.

- new_speed:

  Speed to replace missing values as well as values outside min_speed
  and max_speed range. It can be a numeric (in km/h) or a units value
  able to be converted to km/h. By default, `new_speed = NULL` and the
  function uses the distance-weighted mean of the valid speeds of points
  that are not at stops. It is rounded to 3 decimals in km/h, as the
  output speeds are.

- clone:

  Use a copy of the gps_data? Defaults to TRUE. With `FALSE`, `gps_data`
  is updated in place.

## Value

A GPS-like data with adjusted `speed` values and the same columns as
`gps_data`. The columns `timestamp` and `cumtime` are also updated
accordingly. An error is raised if no speed is within range and
`new_speed` is not given.

## Examples

``` r
poa <- read_gtfs(system.file("extdata/poa.zip", package="gtfs2gps")) |>
  gtfstools::filter_by_shape_id("T2-1") |>
  gtfstools::filter_by_weekday(c("monday", "wednesday")) |>
  filter_single_trip()
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

poa_gps <- gtfs2gps(poa)
#> ℹ Converting shapes to sf objects
#> Using 2 threads
#> ✔ Converting shapes to sf objects [57ms]
#> 
#> ℹ Processing the data
#> ✔ Processing the data [60ms]
#> 
poa_gps_new <- adjust_speed(poa_gps)
#> Warning: `adjust_speed()` is deprecated and will be removed in a future version.
#> ℹ We strongly recommend using gtfstools to fix and edit GTFS data before
#>   processing them with gtfs2gps, e.g. with `gtfstools::set_max_speed()` and
#>   `gtfstools::set_min_speed()`.
#> This warning is displayed once per session.
```
