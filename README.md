# pi-orchestrate

Scout / Main Worker / Smart Worker orchestration for [Pi](https://pi.dev), built on `@tintinweb/pi-subagents`. One Main Worker owns the task; a narrow Scout returns evidence; a frontier Smart Worker returns criticism. Ranked model backends with retry. Tested — see Evidence.

## Install

```bash
pi install git:github.com/selftwo/pi-orchestrate
bash $(pi config path 2>/dev/null || echo ~/.pi/agent)/../pi-orchestrate/scripts/setup.sh
```

`setup.sh` copies `agents/` to your global agents dir (backs up existing) and prints the thinking-level block for `settings.json`. Copy `orchestrate.json` to your project's `.harness/` for the ranked retry policy. Requires `@tintinweb/pi-subagents`.

## Use

Say `orchestrate` (skill: `orchestrate`). Routine:

```text
Main Worker → optional Scout(s) → implement → optional Smart Worker review → tests → decision
```

Retry: on 429 / timeout / network / empty output, move to the next ranked backend. Total exhaustion → Main Worker decides with a note. Every run may also fire an `agy` reference leg via `herdr` into the ledger `ref/` — comparison only, never gates.

## Ranks (tested)

Scout: `glm-5.3-flash`/low → `deepseek-v4-flash`/low → `gpt-5.6-luna`/high → `qwen3.8-flash`/low → `agy` headless.
Advisor: `gpt-6-astra`/low → `kimi-k3`/medium → `glm-5.3-flash`/high → `deepseek-v4-flash`/max → `muse-spark-1.3`/xhigh.

## Evidence

14 timed runs over two rounds plus build validation (Scout best-of-3, Advisor best-of-3, Luna-high ×4 task types, Astra-low, Kimi-K3-medium, herdr transport, native subagent): Scouts 25–50s all correct; advisors 49–145s, Astra-low best (7 findings, 52s); external CLI failed 2× on network, hence non-gating. Full report: `docs/TESTED-PROPOSAL.md`.
