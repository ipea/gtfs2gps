# Package index

## Input/output

- [`read_gtfs()`](https://ipea.github.io/gtfs2gps/dev/reference/read_gtfs.md)
  : Read GTFS data into a list of data.tables
- [`write_gtfs()`](https://ipea.github.io/gtfs2gps/dev/reference/write_gtfs.md)
  : Write GTFS data into a zip file

## Convert GTFS to GPS-like table

- [`gtfs2gps()`](https://ipea.github.io/gtfs2gps/dev/reference/gtfs2gps.md)
  : Convert GTFS to GPS-like data given a spatial resolution

## Support functions to edit GTFS input

- [`adjust_arrival_departure()`](https://ipea.github.io/gtfs2gps/dev/reference/adjust_arrival_departure.md)
  : Adjust the arrival and departure times of a GTFS data

- [`adjust_speed()`](https://ipea.github.io/gtfs2gps/dev/reference/adjust_speed.md)
  :

  Adjust the speeds of a gps-like table created with `gtfs2gps`

- [`filter_single_trip()`](https://ipea.github.io/gtfs2gps/dev/reference/filter_single_trip.md)
  : Filter GTFS trips in order to have one trip per shape_id

## Spatial functions to treat GPS output

- [`gps_as_sfpoints()`](https://ipea.github.io/gtfs2gps/dev/reference/gps_as_sfpoints.md)
  : Convert GPS-like data.table to a Simple Feature points object
- [`gps_as_sflinestring()`](https://ipea.github.io/gtfs2gps/dev/reference/gps_as_sflinestring.md)
  : Converts a GPS-like data.table to a LineString Simple Feature (sf)
  object
- [`append_height()`](https://ipea.github.io/gtfs2gps/dev/reference/append_height.md)
  : Add a column with height to GPS data

## Deprecated and defunct

- [`filter_valid_stop_times()`](https://ipea.github.io/gtfs2gps/dev/reference/filter_valid_stop_times.md)
  : Filter GTFS data using valid stop times (deprecated)
- [`gtfs_shapes_as_sf()`](https://ipea.github.io/gtfs2gps/dev/reference/gtfs_shapes_as_sf.md)
  : Convert GTFS shapes to simple feature object (deprecated)
- [`gtfs_stops_as_sf()`](https://ipea.github.io/gtfs2gps/dev/reference/gtfs_stops_as_sf.md)
  : Convert GTFS stops to simple feature object (deprecated)
- [`remove_invalid()`](https://ipea.github.io/gtfs2gps/dev/reference/remove_invalid.md)
  : Remove invalid objects from GTFS data (deprecated)
