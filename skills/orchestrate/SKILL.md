---
name: orchestrate
description: Coordinate multiple agents on large-scope tasks. Use whenever the work is substantial; trivial tasks do not require this skill.
---

# Orchestrate (Pi native, ranked backends)

Remain available to the user while delegating substantive work. Rankings and policy live in `.harness/orchestrate.json`; this skill is the procedure.

## Default routing

```text
Main Worker → optional Scout(s) → implementation → optional Smart Worker review → deterministic checks → decision
```

Small/obvious tasks: Main Worker only. Unfamiliar repo: + Scout. Ambiguous/high-risk: + Scout + Smart Worker. Independent files may parallelize; overlapping edits serialize or use `isolation: worktree`.

## Dispatch

Scouts run narrow, read-only, fresh-context, in parallel at rank 1 (`scout` profile pins it). Override model/thinking per rank on retry:

```js
Agent({ subagent_type: "scout", prompt: "<ONE question + allowed paths + output shape>",
  description: "Scout: <x>", run_in_background: true, inherit_context: false })
// retry: same call + model/thinking of next rank in .harness/orchestrate.json
```

Advisor gate on a frozen slice (objective, criteria, plan/diff, tests, ONE question), rank 1 (`smart-worker` profile pins it):

```js
Agent({ subagent_type: "smart-worker", prompt: "Objective:\n...\nDiff:\n...\nQ: What could still fail?",
  description: "Advisor: <x>", run_in_background: false, inherit_context: false })
```

Leaf guard in every dispatch: "Complete this assignment directly. Do not spawn other agents; your parent's delegation instructions apply only to your parent."

## Retry

On 429, timeout, network error, or empty output: move to the next rank, log the attempt in the ledger. Total exhaustion → Main Worker decides with a written note, never silent block. Scout budget 120s; advisor routine 90s, deep 180s.

## Reference (non-gating)

Every V1-like run also fires agy scout + advisor in the background via herdr with a packed context bundle (task packet plus cited files). Results land in `.harness/runs/<id>/ref/` for later comparison only. Headless waits must poll a done.flag file, never echo-match. agy output never gates acceptance.

## Ledger + approval

Write `.harness/runs/<id>/{task.md,scout/,plan.md,diff.patch,advisor.json,tests.log,decision.md,ref/}`. Acceptance is tests plus your diff review; advisor LGTM is input, not verdict. Use `plannotator review` for diffs, `plannotator annotate` for docs.
