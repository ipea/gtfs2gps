# Plan-First Workflow

**For any non-trivial task, enter plan mode before writing code.** Non-trivial
means more than one file, a change to exported behaviour, a performance change,
or anything taking more than a few minutes. A typo or a one-line obvious fix is
not.

## The protocol

1. **Enter plan mode** (`EnterPlanMode`).
2. **Recall:** read `MEMORY.md` `[LEARN]` entries and the backlog in
   `quality_reports/specs/` for anything relevant.
3. **Explore:** read the affected functions, their helpers, tests and callers.
   Look for existing helpers to reuse before proposing new code.
4. **Clarify:** ask only about genuine decisions (API naming, behaviour
   changes, new dependencies), at most 3–5 questions via `AskUserQuestion`. For
   large or vague tasks, write a spec first (below).
5. **Draft the plan:** context, approach, files to change, tests to add,
   verification, and an explicit list of what is *not* being changed.
6. **Adversarial plan review:** see the next section. Mandatory.
7. **Plan file:** the harness creates the plan file in `quality_reports/plans/`
   when plan mode starts (`plansDirectory` in settings), and it is the only
   file writable in plan mode. It is the plan of record. Write the draft there
   with Status: DRAFT and revise it in place through the review rounds.
8. **Present:** once the reviewers reach consensus, call `ExitPlanMode`.
   Include a short "review outcome" note: what the reviewers cut or changed.
9. **On approval:** rename the file to
   `quality_reports/plans/YYYY-MM-DD_short-description.md`, set Status to
   APPROVED, start the session log, and execute via `orchestrator-protocol.md`
   (contractor mode).

## Adversarial plan review (mandatory)

Every plan is challenged by **two independent adversarial agents** before it is
shown to the user. They are fresh `Plan` subagents (read-only; not `fork`), launched
in parallel in one message, each given the draft plan and the relevant file
paths. They never see each other's output in the first round.

| Reviewer | Mandate |
|---|---|
| **Minimalist** | Make it smaller. Which steps, files, abstractions, arguments or dependencies are unnecessary? Can an existing helper do this? What is the smallest diff that fully solves the problem? Is anything gold-plating? |
| **Skeptic** | Make it right. What breaks? Edge cases (frequency-based feeds, times past 24:00, stops that don't snap, shapes without trips, `NA` times, empty tables), caller mutation, `ncores = 1` vs `ncores = 2` divergence, units of output columns, performance regressions, back-compat for exported functions, CRAN issues, missing tests. |

Each returns findings as `{severity: CRITICAL|MAJOR|MINOR, finding, proposed_change}`
and a verdict: `APPROVE` or `REVISE`.

**Consensus loop:**
1. Revise the plan to address every CRITICAL/MAJOR finding (or write down why
   it is rejected).
2. Re-run both reviewers on the revised plan, this time with the other
   reviewer's previous findings attached so they can contest them.
3. **Consensus = both return APPROVE.** Stop and save.
4. **Cap: 3 rounds.** If they still disagree, present the plan with the
   unresolved disagreement stated plainly as a decision for the user.

**Simplicity bias:** when the two reviewers conflict, prefer the option with
less code change, unless the Skeptic shows a correctness or CRAN failure.

## Requirements spec (large or ambiguous tasks)

Use it when the task is vague ("improve performance"), has several valid
interpretations, or touches the public API in several places. Write
`quality_reports/specs/YYYY-MM-DD_description.md`. Use
`templates/requirements-spec.md` if present; it is local to the maintainer's
setup.
- Mark requirements MUST / SHOULD / MAY.
- Give each aspect a clarity status: CLEAR / ASSUMED / BLOCKED.
- Get approval, then plan.

## Plans on disk

Plans survive context compression. Status values: DRAFT → APPROVED →
COMPLETED. Update the status when it changes.

## Session recovery

After compression or in a new session:
1. Read `CLAUDE.md` and the most recent plan in `quality_reports/plans/`.
2. Run `git log --oneline -10` and `git status`.
3. State the current task and next step before continuing.
