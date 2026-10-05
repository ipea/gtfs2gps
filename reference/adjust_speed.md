# Adjust the speeds of a gps-like table created with [`gtfs2gps`](https://ipeagit.github.io/gtfs2gps/reference/gtfs2gps.md)

Some GTFS.zip data sets might have quality issues, for example by
assuming that a trip speed is unreasonably high (e.g. an urban bus
running over 100 Km/h), or in other cases the \`timestamp\` information
might be missing for some route segments. This can lead a gps-like table
to have \`NA\` or unrealistic \`speed\` and \`timestamp\` values. This
function allows the user to adjust the speed of trips and updates
\`timestamp\` values accordingly. The user can adjust the problematic
speeds by either setting a custom constant value, or by considering the
average of all valid trips speed (Default). The columns \`timestamp\`
and \`cumtime\` are updated accordingly.

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
  [`gtfs2gps`](https://ipeagit.github.io/gtfs2gps/reference/gtfs2gps.md).

- min_speed:

  Minimum speed to be considered as valid. It can be a numeric (in km/h)
  or a units value able to be converted to km/h. Values below minimum
  speed will be adjusted. Defaults to 2 km/h.

- max_speed:

  Maximum speed to be considered as valid. It can be a numeric (in km/h)
  or a units value able to be converted to km/h. Values above maximum
  speed will be adjusted. Defaults to 80 km/h.

- new_speed:

  Speed to replace missing values as well as values outside min_speed
  and max_speed range. It can be a numeric (in km/h) or a units value
  able to be converted to km/h. By default, \`new_speed = NULL\` and the
  function considers the average speed of the entire gps data.

- clone:

  Use a copy of the gps_data? Defaults to TRUE.

## Value

A GPS-like data with adjusted \`speed\` values. The columns
\`timestamp\` and \`cumtime\` are also updated accordingly.

## Examples

``` r
poa <- read_gtfs(system.file("extdata/poa.zip", package="gtfs2gps")) |>
  gtfstools::filter_by_shape_id("T2-1") |>
  gtfstools::filter_by_weekday(c("monday", "wednesday")) |>
  filter_single_trip()
#> Unzipped the following files to /tmp/Rtmppl8S8P/gtfsio:
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
#> Converting shapes to sf objects
#> Using 3 CPU cores
#> Processing the data
#> Warning: UNRELIABLE VALUE: Future (<unnamed-1>) unexpectedly generated random numbers without specifying argument 'seed'. There is a risk that those random numbers are not statistically sound and the overall results might be invalid. To fix this, specify 'seed=TRUE'. This ensures that proper, parallel-safe random numbers are produced. To disable this check, use 'seed=NULL', or set option 'future.rng.onMisuse' to "ignore". [future <unnamed-1> (d78cb0e9cb32578122748d2cbf354b2d-1); on d78cb0e9cb32578122748d2cbf354b2d@runnervma94yk<6798>]
#> Some 'speed' values are NA in the returned data.
poa_gps_new <- adjust_speed(poa_gps)
```
