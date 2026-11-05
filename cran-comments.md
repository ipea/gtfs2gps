## R CMD check results

── R CMD check results ─────────────────────────────────────────────────────── gtfs2gps 3.0-0 ────
Duration: 2m 5.5s

0 errors ✔ | 0 warnings ✔ | 0 notes ✔

## Submission

gtfs2gps 3.0-0 is a major release. Summary (details in NEWS.md):

* `gtfs2gps()` is rewritten around compiled code ({cpp11}). It converts all
  shapes in one pass and is much faster: 9x to 1,000x on the feeds we tested.
* The {future}/{furrr} worker sessions are replaced by OpenMP threads in the
  compiled step, set by `ncores` (default 2; `ncores = Inf` uses
  `data.table::getDTthreads()`). Examples, tests and the vignette use at most 2
  threads.
* Stops are located along the shapes with
  `gtfstools::interpolate_shape_dist_traveled()`; gtfs2gps now requires
  gtfstools >= 2.0.0, which is on CRAN.
* Breaking output changes:
  * each trip runs from its first to its last timed stop;
  * `speed`, `dist`, `cumdist` and `cumtime` are rounded to 3 decimals;
  * timestamps wrap at midnight;
  * trips of shapes shared by several routes or stop patterns are now all
    converted;
  * `gps_as_sflinestring()` returns one segment per interval between stops.
* Deprecated, still working:
  * `gtfs_shapes_as_sf()`, `gtfs_stops_as_sf()`, `remove_invalid()` and
    `filter_valid_stop_times()` warn on every call;
  * `adjust_arrival_departure()` and `adjust_speed()` warn once per session.

  Users are pointed to the {gtfstools} equivalents.
* Dependencies:
  * added {cli} and {rlang};
  * removed {furrr}, {future}, {parallelly}, {progressr} and {Rcpp} (replaced
    by {cpp11} in LinkingTo).

## Test environments

* Local: Windows 11, R 4.5.1 (2026-11-05)
* TODO: win-builder, R-devel and R-release (`devtools::check_win_devel()`,
  `devtools::check_win_release()`)
* TODO: R-hub, Linux (R-devel, incl. a clang/OpenMP build) and macOS
  (`rhub::rhub_check()`)



## Reverse dependencies

There is one reverse dependency on CRAN: gtfs2emis (0.1.2).

It calls `gtfs2gps()`, `gps_as_sflinestring()` and `adjust_speed()`. This
release affects it:

* `adjust_speed()` now gives a deprecation warning, once per session. It is a
  warning, not an error.
* The outputs of `gtfs2gps()` and `gps_as_sflinestring()` changed, as listed
  above.

TODO: run `R CMD check` on gtfs2emis against this version, and report the
result here. If anything breaks, contact the gtfs2emis maintainers (the same
team at Ipea) before submitting.
