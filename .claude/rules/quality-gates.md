---
paths:
  - "R/**"
  - "src/**"
  - "tests/**"
  - "vignettes/**"
  - "README.md"
  - "DESCRIPTION"
  - "NEWS.md"
  - "pkgdown/**"
---

# Quality gates (gtfs2gps)

Gates are **pass/fail checks**, not scores. A task is "done" only when the gate
for its checkpoint passes and the output has actually been seen; "should work"
doesn't count.

## Gate 1: Task done / commit

All must hold for the files touched:

| Check | Command | Pass |
|---|---|---|
| Docs + cpp11 registration regenerated | `Rscript -e "devtools::document()"` then `git diff --stat man/ NAMESPACE R/cpp11.R src/cpp11.cpp` | No unexpected content drift (use `git diff`, not `git status`: with `core.autocrlf=true`, regeneration can rewrite line endings only); intended changes staged with the source |
| Targeted tests | `Rscript -e "devtools::test(filter = '<fn>')"` for every touched function (files are `test_<fn>.R`) | 0 failures, 0 new warnings |
| Parallel parity | if `gtfs2gps()` or anything it calls changed: run the affected test/MWE with `parallel = FALSE` and with `parallel = TRUE, ncores = 2` | Identical results |
| Style | read the diff against the surrounding code | Matches the file (conventions A5); there is no `.lintr` here, so lintr is advisory only |
| NEWS | user-facing change | Bullet under the development-version heading (conventions A9) |
| pkgdown index | if an `@export` was added or removed: `Rscript -e "pkgdown::check_pkgdown()"` | No missing or stale topics (config lives in `pkgdown/_pkgdown.yml`) |
| Staging hygiene | `git diff --cached --name-only` | No `.rds`/`.RData`/`.Rhistory`/`.o`/`.dll`/`.zip` outside `inst/extdata`; no workflow files except `CLAUDE.md` and `.claude/rules/` |
| Conventions | `.claude/rules/r-package-conventions.md` checklist | All items hold |

## Gate 2: Pull request

Gate 1, plus:

| Check | Command | Pass |
|---|---|---|
| Full suite | `Rscript -e "devtools::test()"` (slow: `gtfs2gps()` runs in parallel by default) | 0 failures |
| CRAN check | `Rscript -e "devtools::check(args = '--as-cran')"` (background; ~5 minutes) | 0 errors, 0 warnings; each NOTE triaged (pre-existing vs new). The last CRAN submission was 0/0/0 (`cran-comments.md`) |
| Review loop | parallel review lenses (`orchestrator-protocol.md`) | Converged: 0 open CRITICAL/MAJOR |
| Package review | `r-package-reviewer` agent on changed files (local; if absent, apply the conventions checklist manually) | 0 CRITICAL/MAJOR |
| Performance | if the change claims or risks a speed change | `bench::mark` evidence recorded |

## Gate 3: Release (maintainer-driven)

Gate 2, plus `/g2g-package-check` (full report), `devtools::check_win_devel()`
and/or R-hub, a reverse-dependency check, `cran-comments.md` updated, and
`pkgdown/_pkgdown.yml` covering all exports. Claude prepares; the maintainer
bumps the version and submits. gtfs2gps depends on {gtfstools}: check against
the current CRAN gtfstools and, when relevant, its development version (the
package was archived once because gtfstools was).

## Overrides

A gate may be skipped only on an explicit user instruction ("commit anyway"),
and the reason is recorded in the commit body and the session log. Never use
`git commit --no-verify`. This repo has no pre-commit hooks, so Gate 1 is the
only guard.

## Pre-existing failures

If a gate fails for reasons unrelated to the change, don't fix it as a drive-by.
Report it, confirm it also fails on `master`, and add it to the backlog
(`quality_reports/specs/`).
