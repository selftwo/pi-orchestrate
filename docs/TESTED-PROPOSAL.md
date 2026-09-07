# Orchestration for Pi: tested proposal (Scout / Main Worker / Smart Worker)

**Recommendation first:** run orchestration natively in Pi for V1 — one Main Worker you talk to, plus narrow Scout and Smart Worker calls with different models and thinking levels. Add a headless Scout through `herdr` + `agy` later as an optional second engine, not as the default. The advisor gate stays native: the external CLI failed twice on network during these tests, and the native advisors caught real bugs both times.

This document is the single report. It covers what was tested, what the runs proved, the three options with trade-offs, and the exact setup to approve. No skills or extensions were written — nothing to install to use this. Status: tested in two rounds (exp-001, exp-002); round-2 feedback incorporated below, needs final review.

## Question

Can the Codex Scout / Worker / Smart Worker pattern run on Pi with `@tintinweb/pi-subagents`, using the same CLI with different models — and can one role flip to a separate headless CLI driven through `herdr`?

## Short answer on the patterns

Codex varies reasoning effort inside one model family: Scout on Light/low, Worker on Medium, Smart Worker on High. RepoPrompt implements the same three jobs with different nouns: Context Builder (discovery), Oracle (deep-reasoning plan), Orchestrator (dispatch plus verification against `Plan.md`, with managed worktrees). The durable idea in both: **the Main Worker owns judgment, the Scout returns bounded evidence, the Smart Worker returns independent criticism, artifacts carry state, deterministic checks decide.** Models and CLIs are interchangeable backends. That is what the tests below verify on your machine.

## What was tested (7 runs, all on btw/)

Ground truth for grading: thread markdown is written by `writeThreadFile()` in `btw/src/btw-files.ts:112-122` (write at line 115), called from `mirrorThread()` in `btw/src/index.ts:79`. Clipboard copy lives in `btw/src/clipboard.ts` (`copyTextToClipboard`, `execSync` with 5s timeout, returns `{ok, detail}`).

### Scout round — best of 3, same question

Question: "Locate where btw thread markdown files are written to disk. Return file paths with line ranges plus function names. No code changes. Under 15 lines."

| Run | Runtime and path | Time | Grade |
|---|---|---|---|
| S1 | `pi -p`, `opencode-go/deepseek-v4-flash`, thinking low | 25s | Correct core: `btw-files.ts:112-122`, line 115, caller `index.ts:76-82` |
| S2 | `pi -p`, `opencode-go/glm-5.3-flash`, thinking low | 33s | Correct plus extras: `updateIndex()` at `btw-files.ts:200-207`, `threadFileName()` at `store.ts:49` |
| S3 | `agy -p --effort low` via `herdr pane split` + `pane run` + file poll + `pane close` | 50s | Correct minimal: `btw-files.ts:L112-121`, line 115 |

Raw outputs are kept under `.harness/runs/exp-001/scout/` (`pi-deepseekv4.txt`, `pi-glm53flash.txt`, `agy-herdr.txt`).

Best of 3: GLM most complete, DeepSeek fastest correct, agy correct and proves the headless path works. Any of the three is a usable Scout. The agy run matters because it went through `herdr` transport end to end.

### Advisor round — best of 3, same question

Question: "Given the write path (`btw-files.ts:115`) and clipboard path (`clipboard.ts`, `execSync pbcopy`, 5s timeout), a proposal copies the file path to clipboard synchronously and returns success without verifying fsync or beyond the ok flag. List concrete failure modes with severity and file:line evidence. Max 20 lines. Advisory only."

| Run | Runtime and path | Time | Grade |
|---|---|---|---|
| A1 | `pi -p`, `deepseek-v4-flash`, thinking high | 145s | Deepest: phantom path from swallowed write error (`btw-files.ts:117-120`), clipboard hijack on every mirror (`index.ts:243-254` vs explicit `/btw-copy` at `:404`), `wl-copy` exit-0 false confidence, sync/async mismatch, missing feedback channel, fsync correctly dismissed |
| A2 | `pi -p`, `glm-5.3-flash`, thinking high | 50s | Same top bugs, concise: swallowed error, main-thread blocking, ok-flag limits, fsync dismissed, plus UX note |
| A3 | `agy -p --effort high --model gemini-3.8-flash-high` via herdr, then direct retry | Fail + fail | `Error: There was a network issue connecting to the server` twice; zero bytes out |

Raw outputs are kept under `.harness/runs/exp-001/advisor/`.

Best of 3: GLM wins routine gates (same bugs as DeepSeek at one-third the latency). DeepSeek wins high-stakes depth (extra findings: hijack-every-mirror, feedback channel) but needs a 150s+ budget. agy/Antigravity as advisor is disqualified for now on reliability, not quality — no output to grade.

### Variation — native subagent, best of 2 shape

A second narrow question ("how does `clipboard.ts` implement copy — which commands, timeout, return shape?") went through the native `Explore` subagent. Result: 8 precise lines (pbcopy `:17-19`, clip `:21-23`, wl-copy/xclip/xsel `:26-30`, clip.exe `:42-43`, timeout `:11-14`), 7,030 tokens, about $0.0003. This proves the in-process subagent path returns structured evidence with transcripts, independent of the headless path.

### Transport proofs (herdr)

Verified working from inside Herdr (`HERDR_ENV=1`): `pane list`, `pane split --no-focus`, `pane run`, `pane read`, `pane close`. One real gotcha found: `pane wait-output --match DONE_MARKER` matched the command echo itself instead of completion. Fix used in the passing runs: the remote command touches a `done.flag` file at the end, and the waiter polls for the file locally. Any headless adapter must use file-or-exit-code polling, never echo matching.

## Options

### Option A — native Pi orchestration (recommended for V1)

Same `pi` CLI, three roles separated by profile plus model/thinking: Scout on a cheap fast model at low thinking with read-only tools and no delegation; Main Worker on your selected model doing implementation; Smart Worker on a frontier model at high thinking, read-only, advisory only. Dispatch is `Agent({ subagent_type, prompt, description, run_in_background, inherit_context: false })` with a task packet (objective, allowed paths, one question, output shape), results folded back with evidence, deterministic checks (`npm test`, diff review, `plannotator review`) as the acceptance gate.

Evidence for: S1, S2, A1, A2, and the native subagent variation all passed; transcripts and steering come free; no extra processes.

Against: single-vendor blast radius; a wedged parser can still pollute the session (mitigate with timeouts and fresh-context packets).

### Option B — flipped headless Scout via herdr + agy

Same role contract, Scout runtime swapped to `agy -p --effort low` held in a `herdr` pane, file artifact (`task.md` in, `result.json`/`stdout.log`/`exit.code` out) as the return path.

Evidence for: S3 passed end to end through herdr; crash isolation and zero-history-leakage hold by construction.

Against: slower here (50s vs 25-33s), weaker output (minimal vs extras), waiter gotcha above, and A3 shows the external CLI can fail on network with zero output. Genuine read-only needs a copied workspace plus sandbox flags — `herdr`/`tmux` alone enforce nothing.

### Option C — hybrid (proposed V1.1)

Native advisor gate plus two Scout backends behind one name: try native first, flip to headless `agy` when you want a second engine opinion or isolation. The Main Worker's call does not change; routing picks the backend.

Evidence for: combines the winners (S2 native Scout, A2 native advisor) with S3 as fallback.

Against: one small router to maintain.

## What works, what does not

Works: native Scout on DeepSeek-V4-Flash or GLM-5.3-Flash at low thinking; native advisor on GLM (fast gate) or DeepSeek (deep gate); fresh-context packets; file-poll headless transport; evidence-shaped outputs; `plannotator review`/`annotate` as the human gate (already installed).

Does not work yet: agy/Antigravity as a required advisor (network failures, no output); echo-matched waits; prompt-only "don't edit" without tool stripping; full-history inheritance into Scouts; auto-trio on trivial tasks.

## Experiment round 2 (exp-002, per review feedback)

### Luna on high thinking across 4 task types

Same repo, `openai-codex/gpt-5.6-luna` at high thinking. Evidence in `.harness/runs/exp-002/scout/`.

| Task | Time | Grade |
|---|---|---|
| A. Locate thread-file write path (repeat of round 1) | 33s | Correct, ultra-minimal: one line, `btw-files.ts:112-115` |
| B. Clipboard implementation summary | 26s | Correct, dense one-liner: all 6 commands, 5000ms timeout, return shape |
| C. Existing tests for threads/index + gaps | 34s | Correct: `test-panel-render.mjs` covers rendering only; gap is no test for threads/index writes |
| D. API surface of `context.ts` + `panel.ts` | 36s | Correct: all exports with line ranges |

Luna-high verdict: 4/4 correct, 26-36s, consistently terse. High thinking did not buy extra completeness versus GLM-low (which found extras like `updateIndex` in round 1). Use Luna where brevity plus accuracy matters; keep GLM as the completeness pick.

### Astra-low advisor (new default) and Kimi-K3-medium fallback

Same advisor question as round 1. Evidence in `.harness/runs/exp-002/advisor/`.

| Run | Time | Grade |
|---|---|---|
| `openai-codex/gpt-6-astra`, thinking low | 52s | Best advisor so far: 7 findings, precise refs (`index.ts:215,245,254`, `:267`, `:76`), new angles — async contract mismatch, partial-success reporting, atomicity-vs-durability split |
| `opencode-go/kimi-k3`, thinking medium | 49s | Strong fallback: same top bugs plus new angles — cwd leak into clipboard history, ~20s worst-case Linux stall, `notify` fallback option |

Both validate the new defaults: Astra-low first, Kimi-K3-medium fallback. Both beat round-1 latency (50s vs 145s) with equal or better depth.

### agy direct baseline (context-packing reference)

Direct `agy -p --effort low` (no herdr): 43s, correct minimal — same answer as the 50s herdr run. Pane overhead is ~7s; closeness confirms the headless path is sound and the earlier high-effort failures were network/endpoint flakiness, not transport. agy stays as background reference, never as gate.

## Revised V1 setup (nothing written yet)

- `scout` ranking (try in order, next on 429 / timeout / network / empty output): 1 `opencode-go/glm-5.3-flash` / low (most complete) → 2 `opencode-go/deepseek-v4-flash` / low (fastest) → 3 `openai-codex/gpt-5.6-luna` / high (terse, accurate) → 4 `opencode-go/qwen3.8-flash` / low → 5 `agy` headless via herdr / low effort.
- `smart-worker` (advisor) ranking: 1 `openai-codex/gpt-6-astra` / low (best, 52s) → 2 `opencode-go/kimi-k3` / medium (strong fallback, 49s) → 3 `opencode-go/glm-5.3-flash` / high → 4 `opencode-go/deepseek-v4-flash` / max (deepest, budget 150s+) → 5 `opencode-go/muse-spark-1.3-contributor` / xhigh.
- Thinking rule: scoped per-model level from settings (`settings.json` → `modelThinkingLevels`, now covering glm-5.3-flash, gpt-5.6-luna, gpt-6-astra, kimi-k3); role calls pass their tier explicitly, which wins. Unscoped models fall back to high (slow, careful) — assumption, correct me if you meant low.
- Retry rule: on 429, timeout, network error, or empty output, move to the next rank and log the attempt in the ledger. If all ranks exhaust, the Main Worker decides with a written note — never block silently.
- `main worker`: whatever you select per session; owns plan, integration, accept/revise/reject.
- Trigger word: `orchestrate` (unchanged).
- Run ledger: `.harness/runs/<id>/{task.md, scout/, plan.md, diff.patch, advisor.json, tests.log, decision.md, ref/}` — accepted location, plus `ref/` below.
- agy reference pattern: every V1-like run also fires agy scout + advisor in the background via herdr with a packed context bundle (task packet plus cited files). Results land in `ref/` for later comparison only and never gate acceptance. This spends agy usage on calibration, exactly as reviewed.

## Needs your review (updated)

1. Scout ranking above (GLM → DeepSeek → Luna → Qwen → agy) — accept order?
2. Advisor ranking above (Astra-low → Kimi-K3-medium → GLM-high → DeepSeek-max → Muse-Spark-xhigh) — accept?
3. Unscoped-model fallback = high (slow/careful) — or did you mean low?
4. Retry-then-Main-decides on total exhaustion — accept, or hard-fail instead?
5. Say the word and I create the profile/config file set exactly as ranked above.

Reply with answers (or "approved as proposed"). Until then, nothing new will be written.
