# Test whether a GTFS feed is frequency based

Test whether a GTFS feed is frequency based or whether it presents
detailed time table for all routes and trip ids.

## Usage

``` r
test_gtfs_freq(gtfs)
```

## Arguments

- gtfs:

  A GTFS data set stored in memory as a list of data.tables/data.frames.

## Value

A string "frequency" or "simple".
