# Simplify shapes of a GTFS file

Remove points from the shapes of a GTFS file in order to reduce its
size. It uses Douglas-Peucker algorithm internally.

## Usage

``` r
simplify_shapes(gtfs_data, tol = 0)
```

## Arguments

- gtfs_data:

  A list of data.tables read using gtfs2gps::read_gtfs().

- tol:

  Numerical tolerance value to be used by the Douglas-Peucker algorithm.
  The default value is 0, which means that no data will be lost.

## Value

A GTFS data whose shapes is a subset of the input data.
