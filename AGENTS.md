# Agent Working Agreement

This file applies to every coding agent working on this repository, regardless of model or provider.

The repository is the source of truth.

The identity of the previous agent is irrelevant. Never restart work merely because another agent has taken over.

---

## 1. Start of Work

Before substantial work:

1. Read `AGENTS.md`.
2. Read `HANDOFF.md`.
3. Run `git status --short --branch`.
4. Run `git log -5 --oneline --decorate`.
5. Inspect only the files relevant to the current task.
6. Continue from verified existing work instead of repeating completed investigation.

Preserve pre-existing uncommitted changes unless there is a clear reason to modify them.

Never discard another agent's work without understanding it first.

---

## 2. Primary Rule: Do the Work

You are a coding agent, not a project-status assistant.

When the user asks to:

* fix
* continue
* implement
* update
* investigate
* deploy
* test

and the next action can be performed using available tools:

DO IT NOW.

Do not stop after saying:

* "Next steps"
* "Next move"
* "I will inspect..."
* "I will modify..."
* "接下來要做的事"

If the next action can be executed, execute it.

Do not require the user to repeatedly say "continue".

---

## 3. New User Feedback Overrides Previous Assumptions

Real grandMA3 test results from the user are authoritative observations.

If the user says an implementation still does not work, treat the previous implementation as unsuccessful for that requirement.

Do not:

* defend the previous implementation
* repeat the previous commit summary
* simply redeploy the same files
* claim the code is correct because hashes match
* repeat the same failed attempt

Instead:

1. Inspect the current implementation.
2. Identify why the observed result differs from the requirement.
3. Form a new hypothesis.
4. Make the required source-code change.
5. Verify the new diff.
6. Deploy only after the implementation has actually changed when a change is required.

---

## 4. Mandatory Change Workflow

For a requested code or UI behavior change:

Inspect
→ Diagnose
→ Modify
→ Review Diff
→ Validate
→ Deploy when appropriate
→ Verify deployment
→ User real-world test when required
→ Commit when the change is confirmed/coherent

A task is not complete merely because investigation occurred.

A task is not complete merely because deployment occurred.

A task is not complete merely because source and deployed SHA256 hashes match.

---

## 5. Required Source-Diff Gate

When the user requests NEW behavior or reports that existing behavior is wrong, an implementation task normally requires a relevant source change.

Before deployment, inspect:

`git diff`

If the task requires a source change but there is no relevant diff:

DO NOT treat the task as completed.

Continue investigating and modifying.

Do not deploy an unchanged old implementation and report it as a new fix.

---

## 6. Evidence Rules

Never claim something was:

* fixed
* updated
* tested
* deployed
* verified
* committed
* pushed

without direct evidence.

### Modified

Evidence:
`git diff` contains the intended change.

### Validated

Evidence:
the relevant parser, lint, static check, test, or other available validation was actually executed.

### Deployed

Evidence:
an actual copy/deployment command successfully ran.

### Deployment verified

Evidence:
repository and deployed files have matching hashes.

Hash equality proves only that the two files are identical.

It does NOT prove the feature is correct.

### Real-world verified

Evidence:
the user tested it in grandMA3 and reported the behavior.

Do not confuse local validation with real grandMA3 validation.

---

## 7. grandMA3 Local Deployment

Deployment destination:

`C:\ProgramData\MALightingTechnology\gma3_library\datapools\plugins\Update Plugin`

When deployment is appropriate:

1. Validate XML structure.
2. Confirm every referenced Lua component exists.
3. Copy only the intended Plugin XML and referenced runtime files.
4. Calculate SHA256 of repository source.
5. Calculate SHA256 of deployed copy.
6. Confirm hashes match.

Never claim deployment simply because files already exist in the target directory.

---

## 8. Commit Strategy for Real-World UI Development

Do not create unnecessary commits for every speculative UI adjustment.

Preferred workflow for changes requiring grandMA3 visual/runtime validation:

Modify
→ local validation
→ deploy
→ user real-world test
→ iterate if needed
→ commit coherent confirmed state

A commit may be created earlier when useful for safety or handoff, but do not mistake the existence of a commit for successful real-world validation.

---

## 9. Loop Detection

If you notice that you are repeating:

* the same summary
* the same HANDOFF contents
* the same "next steps"
* the same file reads
* the same deployment
* the same old commit
* the same failed fix

STOP.

Determine what NEW action or evidence is missing.

Then perform that action.

Never use repetition as a substitute for progress.

---

## 10. HANDOFF.md Is State, Not Instructions

`HANDOFF.md` is external project memory.

It is NOT:

* an answer template
* a checklist to repeat to the user
* a complete project history
* a roadmap of every future idea

Do not echo HANDOFF sections back to the user unless relevant.

Execute its `Exact Next Action` rather than merely repeating it.

Historical research belongs in `docs/`.

Git history belongs in Git.

---

## 11. Context Efficiency

Keep context small and task-focused.

Prefer:

* targeted file reads
* grep/search
* relevant code ranges
* current `git diff`
* short HANDOFF state
* existing research documents only when needed

Avoid repeatedly loading large historical documents.

When context becomes large:

1. update `HANDOFF.md`
2. ensure the working tree state is accurately recorded
3. start a fresh agent session

A new agent should be able to continue from the repository without needing the previous conversation.

---

## 12. Handoff Between Codex, Qwen, or Other Agents

All agents use the same repository state.

Do not create model-specific handoff files.

Recover state in this order:

1. working tree
2. `HANDOFF.md`
3. recent Git history
4. relevant source code
5. `docs/`

Never redo completed work solely because the previous model was different.

---

## 13. HANDOFF Maintenance

`HANDOFF.md` must describe the CURRENT project state.

Rewrite stale information instead of continually appending history.

Keep it concise.

It should contain only:

* Current Goal
* Current Working State
* Latest Real-World User Test
* Verified Facts
* Current Problem
* Known Failed Attempts relevant to the current problem
* Important Files
* Current Branch / Commit
* Exact Next Action

Do not store long logs, old hashes, every historical version, or old completed milestones in HANDOFF.

Move durable research/history to `docs/` when necessary.

---

## 14. Completion Rule

Before saying a requested implementation is complete, verify the relevant items:

* [ ] Latest user request was addressed
* [ ] Relevant implementation was inspected
* [ ] Root cause was investigated
* [ ] Required source modification actually exists
* [ ] `git diff` was reviewed
* [ ] Relevant local validation was run
* [ ] Deployment was actually executed if required
* [ ] Deployment hashes match if required
* [ ] Real grandMA3 validation is clearly distinguished from local validation
* [ ] HANDOFF reflects the current state
* [ ] No repeated stale next-step summary is being presented as progress

If a required item is false and can still be performed locally, continue working.

Only stop for the user when the next unknown genuinely requires user-side grandMA3 testing or a consequential decision.

---

## Primary Principle

DO THE WORK.

Planning, summaries, Git commits, old results, and deployment verification are not substitutes for implementation.
