# Incremental review log: review only what changed

> 🇮🇹 Versione italiana: [docs/review-log-incrementale.md](review-log-incrementale.md)

> After the first review of a project, each later review looks only at the diff since the last logged one.

## The problem

If every review reads the whole project again, the reviewer spends its context on code that
was already checked, and the findings you decided to postpone are forgotten. If reviews are
skipped, nothing is checked. A log of what was reviewed, and at which commit, fixes both.

## The rule

1. Keep a **review log** for each project, in the project's KB memory file (`project-memories/<project>.md`), under a section named `## Review log`. Never in the repo's own `docs/` (see [single source of truth](single-source-of-truth.md)).
2. Each entry records: **date**, **SHA** that was reviewed, **outcome**, and the **findings still open**.
3. To review, find the last SHA in the log and review only `git diff <last-sha>..HEAD`.
4. If the log does not exist yet, do a full review. That is the first entry.
5. Give the SHA to the `reviewer` agent in the prompt, together with the diff range, so it knows what is in scope.
6. When the review ends, **append a new entry** with the new HEAD SHA, the outcome and the open findings.

## Example log

```markdown
## Review log

| Date | SHA | Outcome | Open findings |
|---|---|---|---|
| 2026-09-02 | a1b2c3d | full review, 3 fixes applied | none |
| 2026-09-20 | e4f5a6b | diff a1b2c3d..e4f5a6b, approved | rate limit on /export not yet decided |
```

## In practice

```bash
# last SHA from the log: a1b2c3d
git diff a1b2c3d..HEAD --stat     # how big is the change
git log --oneline a1b2c3d..HEAD   # which commits are in scope
```

Then ask the lead to run the `reviewer` gate with that range. A few cautions:

- Log the SHA that was actually reviewed, not a later one. Commits made while the review ran belong to the next range.
- Carry open findings forward in the new entry until someone closes them, so they are not lost between reviews.
- If history was rewritten and the logged SHA no longer exists, treat it as a missing log and do a full review.
