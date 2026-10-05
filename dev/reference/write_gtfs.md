# Write GTFS data into a zip file

Write GTFS stored in memory as a list of data.tables into a zipped GTFS
feed, using
[`write_gtfs`](https://rdrr.io/pkg/gtfstools/man/write_gtfs.html). By
default an existing zip file is overwritten; set `overwrite = FALSE` to
raise an error instead.

## Usage

``` r
write_gtfs(gtfs, zipfile, overwrite = TRUE, quiet = FALSE)
```

## Arguments

- gtfs:

  A GTFS data set stored in memory as a list of data.tables/data.frames.

- zipfile:

  The pathname of a .zip file to be saved with the GTFS data.

- overwrite:

  A logical. Whether to overwrite an existing `.zip` file. If `FALSE`
  and `zipfile` already exists, an error is raised. Defaults to `TRUE`.

- quiet:

  A logical. Whether to hide log messages and progress bars. Defaults to
  `FALSE`.

## Value

The GTFS data, invisibly.

## Examples

``` r

# read a gtfs.zip to memory
poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps")) |>
  gtfstools::filter_by_shape_id("T2-1") |>
  filter_single_trip()
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

# write GTFS data into a zip file
write_gtfs(poa, paste0(tempdir(), "/mypoa.zip"))
#> Writing text files to /tmp/RtmpvsnyV4/gtfsio1ab3c450d00
#>   - Writing agency.txt
#>   - Writing calendar.txt
#>   - Writing routes.txt
#>   - Writing shapes.txt
#>   - Writing stop_times.txt
#>   - Writing stops.txt
#>   - Writing trips.txt
#> GTFS object successfully zipped to /tmp/RtmpvsnyV4/mypoa.zip
```
