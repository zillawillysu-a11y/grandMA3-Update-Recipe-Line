# Agent Working Agreement

This file applies to the entire repository. This is a small project; agents should work autonomously, make reasonable decisions from the available evidence, and minimize interruptions. Ask the user only when a decision is genuinely ambiguous, risky, irreversible, or requires authority that has not been granted here.

## Start-of-work checklist

Before substantial work:

1. Read this `AGENTS.md` in full.
2. Read `HANDOFF.md` if it exists.
3. Run `git status` and inspect the current branch.
4. Review recent Git history (for example, `git log -5 --oneline --decorate`).
5. Inspect the relevant code, configuration, tests, and documentation before editing.
6. Continue from useful existing work and recorded investigations instead of repeating them.

Treat pre-existing uncommitted changes as valuable work. Understand and preserve them unless the task explicitly requires modifying them. Do not discard or overwrite another contributor's work without a clear reason.

## Authorized project operations

Agents may, without asking for routine approval:

- Inspect, edit, create, move, rename, and delete project files as needed to complete the task.
- Run tests, builds, linters, formatters, type checks, and other validation.
- Install or update dependencies when reasonably necessary. Respect the project's package manager and update lockfiles consistently.
- Use normal Git operations, including `git status`, `git diff`, `git add`, `git commit`, `git pull`, and `git push`.

Avoid force pushes, history rewrites, hard resets, broad destructive cleanup, and other destructive Git operations unless they are genuinely necessary. If such an operation could lose work or affect collaborators, verify the exact scope and seek confirmation first.

## Implementation principles

- Investigate the existing implementation and reproduce or understand the issue before changing code.
- Fix the root cause rather than layering on a temporary workaround.
- Preserve existing behavior unless the requested task requires a behavior change.
- Keep changes focused. Avoid unrelated refactors, broad rewrites, and gratuitous formatting churn.
- Follow existing project conventions unless there is a compelling reason to improve them.
- Add or update tests when practical for changed behavior.
- Remove temporary debug code, scratch artifacts, junk files, and unnecessary generated output before finishing.
- Do not claim validation that was not run. Record unavailable or failing validation accurately.

## Validation, commit, and push workflow

After a meaningful change:

1. Review `git diff` for correctness, scope, accidental secrets, debug code, and unwanted generated files.
2. Run the most relevant available tests, build, lint, type checks, or validation. Address obvious regressions and errors.
3. Update `HANDOFF.md` with the current state and validation result.
4. Commit the coherent, validated change automatically with a concise, clear commit message.
5. Push the completed commit to the current upstream GitHub branch when a remote is configured and pushing is appropriate.
6. Verify the final Git status and report any remaining changes or push problems.

Do not bundle unrelated user changes into the commit. A task is normally complete only when the requested change is implemented, relevant validation has passed (or limitations are explicitly documented), obvious regressions are addressed, the work is committed, the commit is pushed when a remote is configured, and `HANDOFF.md` reflects the final state.

## grandMA3 local deployment

When a Plugin artifact is complete enough for grandMA3 testing, also synchronize a copy to:

`C:\ProgramData\MALightingTechnology\gma3_library\datapools\plugins\Update Plugin`

- Create the destination directory if it does not exist.
- Every deployable grandMA3 Plugin must include its XML descriptor plus all referenced Lua component files. Follow the XML structure used by installed grandMA3 Plugins (`GMA3` -> `UserPlugin` -> `ComponentLua`) and keep each `FileName` consistent with the deployed Lua filename.
- Copy only the intended runnable Plugin XML, referenced Lua components, and required companion files; do not copy research notes, repository metadata, tests, or temporary files.
- Preserve the repository copy as the source of truth.
- Validate the XML structure and confirm every referenced component exists before copying. After copying, compare source and destination hashes to verify an exact deployment.
- Record the deployed files and verification result in `HANDOFF.md`.
- A local deployment is not a substitute for committing and pushing repository changes.

## Handoff workflow

Maintain `HANDOFF.md` at the repository root as a durable continuation record.

Update it whenever work is paused, incomplete, likely to be continued by another agent, or fully completed. Preserve useful prior context; revise stale sections and add the latest state instead of replacing the file with a vague summary. Keep it concise enough to scan but specific enough that another agent can continue without repeating investigation.

Every handoff must clearly include:

- Current objective
- Current status
- What has been completed
- What remains
- Important technical decisions
- Known issues or blockers
- Failed approaches that should not be repeated
- Relevant files
- Commands used when useful
- Test/build/validation status
- Current branch
- Latest relevant commit
- Recommended next steps

When a task is complete, explicitly mark it complete and record the final validation, commit, and push status. When it is incomplete, state the exact stopping point and the next concrete action.
