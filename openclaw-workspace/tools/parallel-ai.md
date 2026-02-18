# Parallel AI (Research)

- **CLI:** `parallel-research` (bash script at `~/.openclaw/skills/research/scripts/parallel-research`, symlinked to `~/.local/bin/`)
- **API key:** Available as `$PARALLEL_API_KEY` in gateway env vars (openclaw.json). Do NOT use `~/.secrets/parallel/.env` — that path doesn't exist. The secrets dir is `~/.secrets/parallel-task/`.
- **Usage:** `parallel-research create "topic" --processor ultra`, then poll with `parallel-research status <run_id>`, fetch with `parallel-research result <run_id>`
- **`result` latency:** `parallel-research result` can take 5-10s before producing any output (API call latency). Set `yieldMs: 15000` when running via `exec`. Don't kill it prematurely — it's not stuck, just slow to start.
