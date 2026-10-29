# Orchestrator Protocol (contractor mode)

**After the user approves a plan, execute it autonomously:** implement, verify,
review, fix, and repeat until reviews come back dry. Return to the user only
for ambiguity, a decision that is theirs, or a blocker. Nothing in this loop
commits, pushes or opens PRs; that needs an explicit request (`/g2g-commit`).

## The loop

```
Approved plan
  │
  1. IMPLEMENT   smallest change that satisfies the plan; follow
  │              r-package-conventions.md
  2. VERIFY      quality-gates.md Gate 1 (document, targeted tests, lint);
  │              read the output; retry ≤ 2, then escalate
  3. REVIEW      parallel forked reviewers (lenses below), each returns
  │              FINDINGs
  4. REDUCE      dedupe on location+finding; CRITICAL>0 → BLOCK,
  │              MAJOR>0 → REVISE, else PASS
  5. FIX         critical → major; minors fixed if cheap and in scope
  6. RE-VERIFY   Gate 1 again (Gate 2 before a PR)
  │
  └─ converged? (2 consecutive rounds with 0 new CRITICAL/MAJOR)
       yes → report     no → back to 3 with fresh reviewers (cap 5 rounds)
```

## Review lenses for package code

Launch in **one message**, each as a separate fresh subagent (not `fork`) with only the diff,
the plan and the relevant files:

| Lens | Agent | Looks for |
|---|---|---|
| Correctness and GTFS edge cases | `general-purpose` | Logic errors; frequency- vs stop_times-based feeds; times ≥ 24:00:00 and the midnight wrap; stops that fail to snap; shapes with no trips / trips with no shape; `NA` arrival/departure times; units of `speed`/`dist`/`cumdist`/`cumtime`; same result with `parallel = TRUE` and `FALSE` |
| Performance and parallelism | `general-purpose` | Avoidable copies, row loops, repeated joins, `sf` work that `sfheaders`/C++ could do, objects shipped to `future` workers, side effects (`<<-`, messages) lost in workers; asks for `bench::mark` if a speed claim is made |
| Package and CRAN | `r-package-reviewer` (local; if absent, `general-purpose` with `r-package-conventions.md`) | Conventions, roxygen, NAMESPACE, cpp11 registration, tests (including "doesn't change input data"), CRAN policy (cores, writing outside `tempdir()`), back-compat |

Scale down for small changes: a docs-only change needs only the package lens.
Scale up for risky ones: add a second correctness reviewer with a different
fixture focus.

**FINDING format:**
`{lens, severity: CRITICAL|MAJOR|MINOR, location: file:line, finding, evidence, proposed_fix}`.
A CRITICAL must be backed by evidence (a failing input, a quoted line). When
the orchestrator introduces a CRITICAL that no lens raised, it re-verifies it
in a fresh fork before acting on it; if the fork can't ground it, it is
dropped.

## Guards

- **Two strikes:** if the same finding survives rounds N and N+2, stop patching
  and escalate to the user. The design is probably wrong.
- **Scope:** a reviewer finding outside the plan's scope goes to the backlog,
  not into the diff.
- **Pre-existing failures:** don't fix them as drive-bys (see
  `quality-gates.md`).
- **Cost:** keep fan-outs at 3–4 agents. For anything larger, ask first.

## Check-in cadence

Contractor mode means no routine check-ins. Plans may still define explicit
checkpoints (stop, summarise, wait); honour them. While a maintainer is new to
this workflow, plans include a checkpoint at each phase boundary. Drop these
checkpoints once the maintainer says so. Escalate immediately for:
- an API or behaviour decision
- a new dependency
- a gate that can't be passed without changing the plan
- disagreement between reviewers that touches user-facing behaviour

## Report (end of execution)

What changed (files, one line each), gate results with the actual output
summarised, review rounds and what they caught, anything deferred to the
backlog, and open questions. Then update the session log and set the plan
Status to COMPLETED.

## Not automatic

The loop is always started by an approved plan or an explicit skill
invocation. No background daemons, and no unattended loops against shared
branches.
