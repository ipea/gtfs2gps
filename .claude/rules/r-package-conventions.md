---
paths:
  - "R/**/*.R"
  - "src/**"
  - "tests/**/*.R"
  - "man/**"
  - "vignettes/**"
  - "README.md"
  - "DESCRIPTION"
  - "NAMESPACE"
  - "NEWS.md"
  - "pkgdown/**"
---

# gtfs2gps package conventions

**Standard:** a CRAN-ready, correct, fast package. `R CMD check --as-cran`
returns 0 errors, 0 warnings, and only explained notes. New code reads like the
code around it.

Part A describes how gtfs2gps is written today (checked against the source on
2026-10-04). Items tagged **[NEW]** are decisions for new or modified code
only; never apply them to untouched code as drive-bys. Part B is the general
CRAN standard. When they conflict, Part A wins; flag the conflict in the plan.

---

# Part A: gtfs2gps house style

## A1. Namespacing

- **Call dependencies as `package::function()`**: `data.table::`, `sf::`,
  `sfheaders::`, `units::`, `gtfstools::`, `terra::`, `checkmate::`.
- **Existing `@importFrom`** (in `R/utils.R`): data.table `:=`, `%between%`,
  `fifelse`, `%chin%`; `stats::na.omit`; `utils` `head`, `tail`,
  `object.size`; `lwgeom::st_geod_length`; plus
  `@useDynLib gtfs2gps, .registration = TRUE`. Don't add new `@importFrom`
  without a plan; **[NEW]** write `stats::`/`utils::` explicitly in new code
  (existing code has bare `na.omit()`, `object.size()`, `weighted.mean()`).
- Never use `library()`/`require()` in `R/`. Suggested packages are guarded
  with `requireNamespace("pkg", quietly = TRUE)`.
- Column names used with non-standard evaluation go into the
  `utils::globalVariables(c(...))` block in `R/zzz.R` (which also has a second,
  tiny one for `.` and `:=`). Append new names at the end; check for
  duplicates first.

## A2. Inputs, outputs and the two data shapes

gtfs2gps handles two kinds of objects:

| Object | What it is | Produced by |
|---|---|---|
| **GTFS** | a gtfstools `dt_gtfs` list of data.tables, read with only the fields gtfs2gps needs | `read_gtfs()` (wraps `gtfstools::read_gtfs(fields = ...)`) |
| **GPS** | one `data.table`; one row per point; columns `shape_id, trip_id, route_type, id, timestamp, shape_pt_lon, shape_pt_lat, stop_id, stop_sequence, speed, dist, cumdist, cumtime, trip_number` | `gtfs2gps()` |

- **GPS column types are part of the API.** `speed` is `units` km/h, `dist`
  and `cumdist` are `units` m, `cumtime` is `units` s, `timestamp` is
  `data.table::ITime`. Functions that take GPS data (`adjust_speed()`,
  `gps_as_sf*()`, `append_height()`) must accept and return these types. When
  computing, drop units, compute, and restore them before returning
  (`adjust_speed()` is the model). Numeric user arguments for speeds are
  interpreted as km/h and may also be `units` objects.
- **GTFS-side argument names:** `gtfs_data` in `gtfs2gps()` and
  `R/filter_gtfs.R`, `gtfs` elsewhere. Match the file; don't rename existing
  arguments (breaking change).
- `gtfs2gps()` accepts a path or an in-memory GTFS. Keep that.
- **Feeds may be frequency-based** (`frequencies.txt`; `saopaulo.zip` is).
  `test_gtfs_freq()` decides; `gtfs2gps()` converts with
  `gtfstools::frequencies_to_stop_times()`. New code must work for both kinds.
- **Validation:** existing exported functions validate little (ad-hoc
  `stop()`s in `gtfs2gps()` and `read_gtfs()`). **[NEW]** new or modified
  arguments are validated with `checkmate::assert_*` (already in Imports);
  enumerated options with `checkmate::assert_choice()` for a single value
  (e.g. `snap_method`), or `assert_names(subset.of =)` for several.
- Times: `stop_times_to_seconds()` in `R/utils.R` (in place; the caller copies
  first; gtfstools turns malformed strings into `NA` with a
  `gtfstools_malformed_time` warning) and `gtfstools::convert_seconds_to_time()`
  back to strings (non-negative whole seconds only; `NA` becomes `""`).
  GTFS times may exceed 24:00:00, but every `timestamp` returned by
  `gtfs2gps()`, `adjust_speed()` and `gps_as_sflinestring()` wraps at 86400 s;
  elapsed time is carried by `cumtime`. Keep that consistent when touching
  time code.

## A3. data.table, C++ and parallelism

- **Never modify the caller's objects.** Existing models:
  `gtfs2gps()` and `filter_valid_stop_times()` start with
  `data.table::copy()`; `adjust_speed()` exposes `clone = TRUE`;
  `gps_as_sflinestring()` copies before adding columns. Any `:=`/`set*()` on
  a table reachable from the input must be preceded by a copy or guarded by
  an explicit argument. (`gtfs_shapes_as_sf()` used to call `setDT()` on the
  input; since 2026-10-05 it delegates to gtfstools and copies.)
- Use `%chin%` for character membership, keyed / `on =` joins, and `by =`
  grouping. No new row-wise loops. `lapply` over shapes or trips followed by
  `data.table::rbindlist()` is the established pattern for per-group work.
- **C++ (cpp11, since 2026-10-28; formerly Rcpp):** C++ lives in `src/*.cpp`
  with `[[cpp11::register]]` (`cpp_snap_points_nearest1/2`,
  `rcpp_distance_haversine`). After changing a registered signature, regenerate
  `R/cpp11.R` and `src/cpp11.cpp` with `cpp11::cpp_register()`
  (`devtools::document()` also does it); never hand-edit them. cpp11 checks
  argument types strictly (an `int` argument rejects `15.5`), so coerce in R at
  the call site. `src/*.o` / `*.dll` are build artefacts (gitignored); delete
  them before `R CMD INSTALL` from the source tree, which otherwise reuses
  objects built with other flags.
- **Parallelism (since 2026-10-29; formerly furrr/future worker sessions):**
  `gtfs2gps()` converts all shapes in one pass (`feed_to_gps()`), and
  `parallel = TRUE` runs the C++ expansion (`cpp_expand_pattern()`) in
  `ncores` threads of the same R session, default `data.table::getDTthreads()`
  (which respects `OMP_THREAD_LIMIT`, `setDTthreads()` and CRAN's limits).
  - Code inside a threaded loop must not call R: take `REAL()`/`INTEGER()`
    pointers and allocate outputs before the loop, catch exceptions inside it
    and raise them after. Trips are independent and nothing is reduced across
    them, so results don't depend on the number of threads.
  - Any change to that path must give **identical results** with
    `parallel = FALSE` and `parallel = TRUE` (Gate 1).
  - Never use more than 2 threads in tests, examples or vignettes.

## A4. Messages, warnings and errors (cli)

**Decision (2026-10-04, maintainer):** gtfs2gps adopts `cli` for all
user-facing conditions. `cli` goes in `Imports`.

- **Use** `cli::cli_abort()`, `cli::cli_warn()` and `cli::cli_inform()`, never
  base `stop()`, `warning()`, `message()`, `print()` or `cat()` in new or
  modified code. Use inline markup: `{.arg spatial_resolution}`,
  `{.fn gtfs2gps}`, `{.file {path}}`, `{.val {shape_id}}`, `{.cls units}`, and
  pluralisation (`{n} shape{?s}`). Multi-part messages use a named vector
  (`c("Main sentence.", "i" = "hint", "x" = "problem")`).
- **Errors carry a class** when tests or users may want to catch them:
  `class = "gtfs2gps_<topic>_error"` (e.g. `gtfs2gps_empty_file_error`).
  Tests then use `expect_error(..., class = "...")` instead of matching text.
- `cli_abort()` reports the caller automatically; inside internal helpers pass
  `call = rlang::caller_env()` only if `rlang` is already a dependency,
  otherwise accept the default.
- **`quiet` still controls informative output.** `cli_inform()` emits a
  message condition, so `suppressMessages()` / the `quiet` argument keep
  working. Progress: use `cli::cli_progress_step()` for phases and
  `cli::cli_progress_bar()` for loops over shapes, never inside threaded C++ (no
  R calls there, A3). `quiet` hides cli's default display through
  `suppressMessages()`. A step's text is interpolated again when it ends, so it
  must not refer to variables reassigned before then.
- **Migration done (2026-10-28):** no base condition calls remain in `R/`. The
  one exception is `packageStartupMessage()` in `.onAttach`, which CRAN
  requires for startup messages. Id lists in messages use
  `cli::cli_vec(x, list("vec-trunc" = Inf))` so cli doesn't cut them after 20.
- Deprecations: `cli::cli_warn(class = "deprecated_<thing>", ...)` naming the
  replacement, tested with `expect_warning(..., class = "deprecated_<thing>")`,
  kept for at least one CRAN release (see `strategy` in `gtfs2gps()`).
  `lifecycle` is not a dependency.

## A5. Style

- 2-space indent, `<-`, snake_case for new functions and arguments, explicit
  `return()` at the end of functions.
- The code base mostly writes `if(`/`function(` without a space and puts
  data.table arguments on new lines with **leading commas**:
  ```r
  stops_seq[gtfs_data$stops
            , on = "stop_id"
            , c('stop_lat', 'stop_lon') := list(i.stop_lat, i.stop_lon)]
  ```
  Match the file you are editing; don't reformat untouched code.
- There is no `.lintr`; lintr output is advisory. Keep new lines ≲ 100
  columns.
- Remove dead commented-out code only in lines you are already changing.

## A6. Documentation (roxygen2, markdown off)

- Roxygen blocks use explicit `@title` and `@description`, then `@param`,
  `@return`, `@export`, `@examples`. Link with `\code{\link{fun}}` (Markdown
  mode is not enabled in DESCRIPTION; backticks render literally in older
  blocks).
- **Examples** use the bundled fixtures and stay small and fast: read
  `poa.zip`, subset to one shape and one trip.
  ```r
  #' poa <- read_gtfs(system.file("extdata/poa.zip", package = "gtfs2gps")) |>
  #'   gtfstools::filter_by_shape_id("T2-1") |>
  #'   filter_single_trip()
  ```
  Examples longer than ~5 s use `\donttest{}`, never `\dontrun{}`
  (`append_height()` currently uses `\dontrun{}`; backlog).
- Internal functions: `@noRd` (see `R/utils.R`). `test_gtfs_freq()` has
  roxygen without `@export`; match that only if a helper should be documented.
- Every new export is added to `pkgdown/_pkgdown.yml` if it gains a
  `reference:` index (today it has none; check with
  `pkgdown::check_pkgdown()`).
- Never hand-edit generated files:

  | Generated file | Regenerate with |
  |---|---|
  | `NAMESPACE`, `man/*.Rd` | `devtools::document()` |
  | `R/cpp11.R`, `src/cpp11.cpp` | `cpp11::cpp_register()` (`document()` also runs it) |

  `README.md` is hand-written (no `README.Rmd`).

## A7. Tests (testthat, edition 2)

- Files are `tests/testthat/test_<function>.R` (**underscore**). New files
  follow that. DESCRIPTION has no `Config/testthat/edition`, so the suite runs
  in edition 2 (`expect_equal(x, y, tolerance)` positional third argument is
  used). Switching to edition 3 needs a plan.
- Fixtures in `inst/extdata/`: `poa.zip` (stop_times-based, small),
  `saopaulo.zip` (frequency-based), `fortaleza.zip` + `fortaleza-srtm.tif`
  (heights), `berlin.zip`, `warsaw.zip`. Load with
  `system.file("extdata/<x>.zip", package = "gtfs2gps")`.
- Existing tests pin hard-coded expected values (row counts, mean speeds with
  a tolerance). When an algorithm change legitimately moves them, re-derive
  the new values, explain the change in the plan, and never just paste the new
  output.
- **New or modified functions** need at least:
  - an input-type / invalid-argument error test
  - the returned class and GPS column types (`units`, `ITime`) where relevant
  - **"doesn't change input data"**: `old <- data.table::copy(x)`; call;
    `expect_equal(old, x)` (`test_adjust_speed.R` takes the copy but never
    asserts on it; new tests must)
  - both a stop_times-based (`poa`) and a frequency-based (`saopaulo`) feed
    when behaviour can differ
  - if the threaded path changed: `parallel = FALSE` vs `parallel = TRUE,
    ncores = 2` give identical output
- Tests run on CRAN (no global skip in `tests/testthat.R`): keep them fast,
  use ≤ 2 cores, and write only to `tempdir()`. (`test_read_gtfs.R` currently
  copies and unzips `poa.zip` into the working directory; backlog.)
- Restore global state (options, threads, files) with `on.exit()`;
  `withr` is not a dependency.

## A8. Performance

- `gtfs2gps()` is the hot path: for the whole feed it segmentizes, snaps stops (C++),
  computes haversine distances (C++) and expands trips/frequencies. Watch for
  avoidable `copy()`s inside per-trip loops, `sf` calls where `sfheaders` or
  C++ would do, repeated `sf::st_coordinates()` on the same object, and work
  repeated per shape or per pattern that could be done once for the feed.
- **A claimed speed-up needs evidence:** `bench::mark(old = ..., new = ...,
  check = FALSE)` on at least `poa.zip` (plus `saopaulo.zip` when frequencies
  matter), results compared with `all.equal()`, and timings recorded in the
  plan or session log. Benchmark with `parallel = FALSE` unless parallel
  overhead is the subject. `bench` is a dev tool, not a dependency.
- Don't add a hard dependency (Imports) without a plan that justifies it.

## A9. NEWS.md

The file starts with `# log history of gtfs2gps package development`, then one
`# gtfs2gps vX.Y-Z` section per release with nested bullets:

```
# gtfs2gps (development version)

* Major changes
  * `fun()` now ... Closes #123.

* Minor changes
  * Fixed a bug in `fun()` that ... (#123). PR contribution by @handle.
```

Add the `(development version)` heading if absent; the maintainer renames it at
release. Credit external contributors.

## A10. Figures (vignette, README, pkgdown)

- **[NEW] Publication-ready standard for new or modified figures:** one
  consistent theme, a colour-blind-safe palette (viridis / Okabe-Ito),
  labelled axes with units, fixed `fig.width`/`fig.height`/`dpi` in chunk
  options, maps in EPSG 4326 or a stated projected CRS. Plotting packages stay
  in Suggests and chunks are gated with `requireNamespace()`.
- Existing figures are restyled only through a plan.

---

# Part B: general CRAN standard

- **DESCRIPTION:** `Imports` for code in `R/`, `Suggests` for
  tests/vignettes/optional paths, `Depends` only for the R version. Version
  floors only when a feature requires them (note: the native pipe `|>` is
  used in `R/`, examples and tests, which requires R ≥ 4.1, while DESCRIPTION
  says `Depends: R (>= 3.5)`; backlog). `Authors@R` with
  roles.
- **Docs:** every export documents all `@param`s, `@return`, and runnable
  `@examples`. Use `\donttest{}` for slow-but-correct examples; never use
  `\dontrun{}` to hide errors.
- **Red flags:**

| Red flag | Do instead |
|---|---|
| `library()`/`require()` in `R/` | `pkg::fun()` |
| Writing outside `tempdir()` | Write only to `tempdir()` or user-supplied paths (`filepath`) |
| `<<-` | Return values |
| `print()`/`cat()`/`message()`/`stop()`/`warning()` in new code | `cli::cli_inform()`/`cli_abort()`/`cli_warn()`, informative output suppressed by `quiet` |
| `options()`/`par()`/threads changed, not restored | `on.exit(..., add = TRUE)` |
| More than 2 cores in tests/examples/vignettes | `ncores = 2` or `parallel = FALSE` |
| `T`/`F` | `TRUE`/`FALSE` |
| Unvalidated enumerated arg | `checkmate::assert_choice()` (A2) |
| `==` on doubles or on `units` vs numeric | tolerance / `all.equal()`; compare `units` with `units::set_units()` |
| Implicit `na.rm` on GPS/GTFS data in new code | State `na.rm` explicitly |
| Growing vectors in loops | Pre-allocate or vectorise |

- **Versioning:** versions look like `2.1-2`; dev versions append `.9000`.
  The maintainer bumps release versions; Claude never does.

## Checklist (new or modified code)

```
[ ] pkg::fun() everywhere (except the existing data.table @importFrom operators)
[ ] input data not modified (copy() or explicit clone arg); test proves it
[ ] new/changed args validated with checkmate
[ ] GPS column types preserved (units km/h, m, s; ITime timestamp)
[ ] works for stop_times-based and frequency-based feeds; tested on both when relevant
[ ] threaded path: identical results parallel = FALSE vs TRUE; no R API inside threads
[ ] ≤ 2 cores and tempdir() only in tests/examples/vignettes
[ ] cli::cli_abort/cli_warn/cli_inform (classed errors); touched functions fully migrated; messages respect quiet
[ ] style matches the file (leading-comma data.table calls, explicit return())
[ ] roxygen: @title/@description/@param/@return/@examples on poa subset
[ ] devtools::document() run; cpp11 registration regenerated, not hand-edited
[ ] NEWS.md bullet for user-facing changes
[ ] perf claims backed by bench::mark with equal results
```

## Cross-references

- [`quality-gates.md`](quality-gates.md): when each check must pass.
- `.claude/agents/r-package-reviewer.md` enforces this rule. It is local to the
  maintainer's setup and may be absent in a fresh clone; if so, apply the
  checklist manually.
