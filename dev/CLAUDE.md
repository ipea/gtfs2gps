# CLAUDE.md — gtfs2gps

**gtfs2gps** is an R package that converts public transport data in GTFS
format into GPS-like records: one `data.table` row per vehicle position,
with timestamps, distances and speeds interpolated along each trip’s
shape at a given spatial resolution. It also converts GTFS and GPS data
to `sf`. Built on `data.table`, `sf`/`sfheaders`, Rcpp, and
`future`/`furrr` for parallelism; GTFS reading/writing and filtering are
delegated to {gtfstools}. Published on CRAN; developed by Ipea
(ipeaGIT). Maintainer (cre): Pedro R. Andrade; authors include Rafael H.
M. Pereira and Joao Bazzo. License MIT. Docs:
<https://ipeagit.github.io/gtfs2gps/>. Default branch: `master`.

------------------------------------------------------------------------

## Core principles

- **Correct positions, times and speeds first.** Output columns carry
  units (`speed` km/h, `dist`/`cumdist` m, `cumtime` s) and `ITime`
  timestamps; those types are part of the API.
- **Performance is a feature.** Vectorised `data.table` code, C++ for
  hot loops, no avoidable copies. Any claimed speed-up needs a
  `bench::mark()` comparison with equal results checked.
- **Never surprise the caller.** Functions don’t modify the input GTFS
  or GPS data
  ([`data.table::copy()`](https://rdrr.io/pkg/data.table/man/copy.html),
  or an explicit `clone` argument).
- **Parallel = sequential.**
  [`gtfs2gps()`](https://ipea.github.io/gtfs2gps/dev/reference/gtfs2gps.md)
  must give the same result with `parallel = TRUE` and
  `parallel = FALSE`.
- **CRAN-ready at all times.** `R CMD check --as-cran`: 0 errors, 0
  warnings. Tests run on CRAN: ≤ 2 cores, write only to
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html).
- **Plan first.** Enter plan mode before non-trivial tasks. Every plan
  must be reviewed by two adversarial agents that improve it and make it
  simpler, with as little code intervention as possible. Present the
  plan only when both agents reach consensus (max 3 rounds, then
  escalate the disagreement). Plans live in `quality_reports/plans/`.
- **Verify after.** Every task ends with the gates below, not with
  “should work”.
- **Learn from corrections.** Log `[LEARN:category] wrong → right` in
  `MEMORY.md`.
- **Messages via cli.** Errors, warnings and messages use
  [`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html)/`cli_warn()`/`cli_inform()`;
  base
  [`stop()`](https://rdrr.io/r/base/stop.html)/[`message()`](https://rdrr.io/r/base/message.html)
  calls are being migrated (conventions A4).
- **Code style.** Use `package::function()` in new code. Exceptions are
  the data.table operators already imported (`:=`, `%chin%`,
  `%between%`, `fifelse`). Otherwise match the style of the file you are
  editing.

Conventions are in
[`.claude/rules/r-package-conventions.md`](https://ipea.github.io/gtfs2gps/dev/.claude/rules/r-package-conventions.md);
gates are in
[`.claude/rules/quality-gates.md`](https://ipea.github.io/gtfs2gps/dev/.claude/rules/quality-gates.md).

------------------------------------------------------------------------

## Repository map

    gtfs2gps/
    ├── DESCRIPTION, NAMESPACE        # NAMESPACE is roxygen-generated; never hand-edit
    ├── R/
    │   ├── gtfs2gps.R                # core: per-shape corefun() run via furrr::future_map
    │   ├── mod_updates.R             # internal: per-trip / frequency expansion (update_freq, update_dt)
    │   ├── read_gtfs.R, write_gtfs.R # thin wrappers around gtfstools
    │   ├── filter_gtfs.R             # filter_single_trip, filter_valid_stop_times, remove_invalid
    │   ├── adjust_speed.R, adjust_arrival_departure.R, append_height.R
    │   ├── gps_as_sfpoints.R, gps_as_sflinestring.R, gtfs_as_sf.R, simplify_shapes.R
    │   ├── test_gtfs_freq.R          # "frequency" vs "simple" feed
    │   ├── utils.R                   # @importFrom, globalVariables, time helpers
    │   ├── zzz.R                     # .onLoad / .onAttach
    │   └── RcppExports.R             # generated; never hand-edit
    ├── src/                          # Rcpp: snap_points.cpp, distance_calcs.cpp (+ generated RcppExports.cpp)
    ├── tests/testthat/               # test_<function>.R (underscore); suite also runs on CRAN
    ├── inst/extdata/                 # fixtures: poa.zip, saopaulo.zip (frequencies), fortaleza.zip (+ srtm.tif), berlin.zip, warsaw.zip
    ├── vignettes/intro_to_gtfs2gps.Rmd
    ├── README.md                     # hand-written (no README.Rmd)
    ├── NEWS.md                       # user-facing changelog
    ├── pkgdown/_pkgdown.yml
    ├── .github/workflows/            # R-CMD-check matrix, test-coverage, pkgdown
    ├── demo/                         # shipped demos (poa, sp, fortaleza); still use %>% and dplyr
    └── prep_data/, tests_joao/, tests_rafa/   # maintainer scratch; Rbuildignored, don't edit unless asked

Exports: `gtfs2gps` · `read_gtfs`/`write_gtfs` · `filter_single_trip`,
`filter_valid_stop_times`, `remove_invalid` · `adjust_speed`,
`adjust_arrival_departure`, `append_height` · `gps_as_sfpoints`,
`gps_as_sflinestring`, `gtfs_shapes_as_sf`, `gtfs_stops_as_sf`.

Local-only workflow files (gitignored and Rbuildignored): `MEMORY.md`,
`quality_reports/`, `templates/`, and everything in `.claude/` except
`rules/`.

------------------------------------------------------------------------

## Commands

``` r

devtools::load_all()
devtools::document()                         # regenerate man/, NAMESPACE, RcppExports
devtools::test()                             # full suite (slow: parallel gtfs2gps)
devtools::test(filter = "adjust_speed")      # matches tests/testthat/test_adjust_speed.R
devtools::check(args = "--as-cran")          # ~5 min; run in background
pkgdown::build_site()
covr::package_coverage()
```

- Compiled code needs a toolchain (Rtools on Windows).
  `core.autocrlf=true` here, so regenerated files can show
  line-ending-only diffs: check drift with `git diff`, not `git status`.
- [`gtfs2gps()`](https://ipea.github.io/gtfs2gps/dev/reference/gtfs2gps.md)
  defaults to `parallel = TRUE` with `availableCores() - 1` workers; for
  quick local checks pass `parallel = FALSE`.

------------------------------------------------------------------------

## Quality gates (summary)

| Checkpoint | Must hold |
|----|----|
| Commit | `document()` produces no content drift (`git diff`, incl. RcppExports); tests for touched functions pass; parallel/sequential parity if the worker path changed; `NEWS.md` entry for user-facing changes |
| PR | Full `test()` passes; `check(--as-cran)` gives 0 errors / 0 warnings, NOTEs triaged; review loop converged; `r-package-reviewer` 0 CRITICAL/MAJOR |
| Release | `/g2g-package-check`; win-builder + rhub; reverse-dependency check; compatibility with current {gtfstools}; `cran-comments.md` updated |

Never use `--no-verify`. Details: `.claude/rules/quality-gates.md`.

------------------------------------------------------------------------

## Skills and agents

These are local to the maintainer’s Claude setup and are not in git. In
a fresh clone, follow the rules in `.claude/rules/` directly.

Project skills carry a `g2g-` prefix so user-level skills with the same
base name can’t shadow them. **In this repo, always use the `g2g-`
version:** use `/g2g-commit`, never a generic `/commit` that merges to
`master`. Where user-level rules conflict with `.claude/rules/`, the
project rules win.

- `/g2g-package-check`: document, test, check `--as-cran`, triage,
  reviewer report.
- `/g2g-commit`: Gate 1, then branch and commit. Push and PR only when
  asked, after Gate 2. **Merging to `master` only on explicit request.**
- `/g2g-diagnose`: root-cause a failing test or wrong result.
- `/g2g-checkpoint`, `/g2g-compress-session`, `/context-status`: session
  state.
- `/g2g-learn`: turn a session discovery into a reusable skill.
- Agent `r-package-reviewer`: read-only CRAN and convention review of
  package source.

------------------------------------------------------------------------

## Working mode

1.  **Plan:** for non-trivial tasks, enter plan mode, explore, ask only
    about real decisions, pass the adversarial plan review, and get
    approval.
2.  **Execute (contractor mode):** after approval, work autonomously
    through implement → verify → parallel review → fix, looping until
    reviews come back dry (see
    `.claude/rules/orchestrator-protocol.md`). Come back only for
    ambiguity or a decision that belongs to the user.
3.  **Report:** summarise what changed, gate results, open questions;
    log the session.

No commits, pushes, PRs, merges, version bumps or `.github/workflows/`
changes without an explicit request. Never hand-edit generated files
(`NAMESPACE`, `man/*.Rd`, `R/RcppExports.R`, `src/RcppExports.cpp`).
