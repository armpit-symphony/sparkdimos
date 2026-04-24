# CLI Reference

The `LIMA` CLI manages the full lifecycle of a LIMA robot stack — start, stop, inspect, and interact.

## Global Options

Every [`GlobalConfig`](/docs/usage/configuration.md) field is available as a CLI flag. Flags override environment variables, `.env`, and blueprint defaults.

```bash
LIMA [GLOBAL OPTIONS] COMMAND [ARGS]
```

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--robot-ip` | TEXT | `None` | Robot IP address |
| `--robot-ips` | TEXT | `None` | Multiple robot IPs |
| `--simulation` / `--no-simulation` | bool | `False` | Enable MuJoCo simulation |
| `--replay` / `--no-replay` | bool | `False` | Use recorded replay data |
| `--replay-dir` | TEXT | `go2_sf_office` | Replay dataset directory name |
| `--new-memory` / `--no-new-memory` | bool | `False` | Clear persistent memory on start |
| `--viewer` | `rerun\|rerun-web\|rerun-connect\|foxglove\|none` | `rerun` | Visualization backend |
| `--n-workers` | INT | `2` | Number of forkserver workers |
| `--memory-limit` | TEXT | `auto` | Rerun viewer memory limit |
| `--mcp-port` | INT | `9990` | MCP server port |
| `--mcp-host` | TEXT | `0.0.0.0` | MCP server bind address |
| `--dtop` / `--no-dtop` | bool | `False` | Enable live resource monitor overlay |
| `--obstacle-avoidance` / `--no-obstacle-avoidance` | bool | `True` | Enable obstacle avoidance |
| `--detection-model` | `qwen\|moondream` | `moondream` | Vision model for object detection |
| `--robot-model` | TEXT | `None` | Robot model identifier |
| `--robot-width` | FLOAT | `0.3` | Robot width in meters |
| `--robot-rotation-diameter` | FLOAT | `0.6` | Robot rotation diameter in meters |
| `--planner-strategy` | `simple\|mixed` | `simple` | Navigation planner strategy |
| `--planner-robot-speed` | FLOAT | `None` | Planner robot speed override |
| `--mujoco-camera-position` | TEXT | `None` | MuJoCo camera position |
| `--mujoco-room` | TEXT | `None` | MuJoCo room model |
| `--mujoco-room-from-occupancy` | TEXT | `None` | Generate room from occupancy map |
| `--mujoco-global-costmap-from-occupancy` | TEXT | `None` | Generate costmap from occupancy |
| `--mujoco-global-map-from-pointcloud` | TEXT | `None` | Generate map from point cloud |
| `--mujoco-start-pos` | TEXT | `-1.0, 1.0` | MuJoCo robot start position |
| `--mujoco-steps-per-frame` | INT | `7` | MuJoCo simulation steps per frame |

### Configuration Precedence

Values cascade (later overrides earlier):

1. `GlobalConfig` default → `simulation = False`
2. `.env` file → `LIMA_SIMULATION=true`
3. Environment variable → `export LIMA_SIMULATION=true`
4. Blueprint definition → `.global_config(simulation=True)`
5. CLI flag → `LIMA --simulation run ...`

Environment variables and `.env` values must be prefixed with `LIMA_`.

---

## Commands

### `LIMA run`

Start a robot blueprint.

```bash
LIMA run <blueprint> [<blueprint> ...] [--daemon] [--disable <module> ...]
```

| Option | Description |
|--------|-------------|
| `--daemon`, `-d` | Run in background (double-fork, health check, writes run registry) |
| `--disable` | Module class names to exclude from the blueprint |

```bash
# Foreground (Ctrl-C to stop)
LIMA run unitree-go2

# Background (returns immediately)
LIMA run unitree-go2-agentic --daemon

# Replay with Rerun viewer
LIMA --replay --viewer rerun run unitree-go2

# Real robot
LIMA run unitree-go2-agentic --robot-ip 192.168.123.161

# Compose modules dynamically
LIMA run unitree-go2 keyboard-teleop

# Disable specific modules
LIMA run unitree-go2-agentic --disable OsmSkill WebInput
```

When `--daemon` is used, the process:
1. Builds and starts all modules (foreground — you see errors)
2. Runs a health check (polls worker PIDs)
3. Forks to background, writes a run registry entry
4. Prints run ID, PID, log path, and MCP endpoint

#### Adding a New Blueprint

Define a module-level `Blueprint` variable and register it in `all_blueprints.py`:

```bash
pytest LIMA/robot/test_all_blueprints_generation.py
```

This auto-generates the registry. See [blueprints](/docs/usage/blueprints.md) for composition details.

### `LIMA status`

Show the running LIMA instance.

```bash
LIMA status
```

Reads the run registry, verifies the PID is alive, and displays: run ID, PID, blueprint name, uptime, log path, and MCP port.

### `LIMA stop`

Stop the running LIMA instance.

```bash
LIMA stop [--force]
```

| Option | Description |
|--------|-------------|
| `--force`, `-f` | Immediate SIGKILL (skip graceful SIGTERM) |

Default behavior: SIGTERM → wait 5s → SIGKILL. Cleans up the run registry entry.

### `LIMA restart`

Restart the running instance with the same original arguments.

```bash
LIMA restart [--force]
```

| Option | Description |
|--------|-------------|
| `--force`, `-f` | Force kill before restarting |

Reads saved CLI args from the run registry, stops the current instance, then re-runs with the same arguments.

### `LIMA log`

View logs from a LIMA run.

```bash
LIMA log [OPTIONS]
```

| Option | Description |
|--------|-------------|
| `--follow`, `-f` | Follow log output (like `tail -f`) |
| `--lines`, `-n` | Number of lines to show (default: 50) |
| `--all`, `-a` | Show full log |
| `--json` | Raw JSONL output (for piping to `jq`) |
| `--run`, `-r` | Specific run ID (defaults to most recent) |

```bash
LIMA log                    # last 50 lines, human-readable
LIMA log -f                 # follow in real time
LIMA log -n 100             # last 100 lines
LIMA log --json | jq .event # raw JSONL, extract events
LIMA log -r 20260306-143022-unitree-go2  # specific run
```

All processes (main + workers) write to the same `main.jsonl`. Filter by module:

```bash
LIMA log --json | jq 'select(.logger | contains("RerunBridge"))'
```

### `LIMA list`

List all available blueprints.

```bash
LIMA list
```

### `LIMA show-config`

Print resolved GlobalConfig values and their sources.

```bash
LIMA show-config
```

---

## Agent & MCP Commands

### `LIMA agent-send`

Send a text message to the running agent via LCM.

```bash
LIMA agent-send "walk forward 2 meters"
```

Works with any agentic blueprint — does not require MCP. Publishes directly to the `/human_input` LCM topic.

### `LIMA mcp`

Interact with the running MCP server. **Requires a blueprint that includes `McpServer`** — for example `unitree-go2-agentic-mcp`. The MCP server runs at `http://localhost:9990/mcp` by default (`--mcp-port` / `--mcp-host` to override).

To add MCP to a blueprint, include both `McpServer` (exposes skills as HTTP tools) and `mcp_client()` (LLM agent that fetches tools from the server):

```python
from LIMA.agents.mcp.mcp_client import mcp_client
from LIMA.agents.mcp.mcp_server import McpServer

my_mcp_blueprint = autoconnect(
    my_robot_stack,
    McpServer.blueprint(),
    mcp_client(),
    my_skill_containers,
)
```

#### `LIMA mcp list-tools`

List all available skills exposed by the MCP server.

```bash
LIMA mcp list-tools
```

Returns JSON with tool names, descriptions, and parameter schemas.

#### `LIMA mcp call`

Call a skill by name.

```bash
LIMA mcp call <tool_name> [--arg key=value ...] [--json-args '{}']
```

| Option | Description |
|--------|-------------|
| `--arg`, `-a` | Arguments as `key=value` pairs (repeatable) |
| `--json-args`, `-j` | Arguments as a JSON string |

```bash
LIMA mcp call relative_move --arg forward=0.5
LIMA mcp call relative_move --json-args '{"forward": 2.0, "left": 0, "degrees": 0}'
LIMA mcp call observe
LIMA mcp call land
```

#### `LIMA mcp status`

Show MCP server status — PID, uptime, deployed modules, skill count.

```bash
LIMA mcp status
```

#### `LIMA mcp modules`

List deployed modules and their skills.

```bash
LIMA mcp modules
```

---

## Standalone Tools

These are installed as separate entry points and can be run directly without the `LIMA` prefix.

### `humancli`

Interactive terminal for sending messages to the running agent.

```bash
humancli
```

### `lcmspy`

Monitor LCM messages in real time.

```bash
lcmspy
```

### `agentspy`

Monitor agent messages and tool calls.

```bash
agentspy
```

### `dtop`

Live resource monitor TUI — CPU, memory, and process stats. Can also be activated during a run with `--dtop`:

```bash
LIMA --dtop run unitree-go2
```

Or run standalone:

```bash
dtop
```

### `rerun-bridge`

Launch the Rerun visualization bridge as a standalone process (outside of a blueprint).

```bash
rerun-bridge
```

Also available as `LIMA rerun-bridge`.

---

## File Locations

| Path | Contents |
|------|----------|
| `~/.local/state/LIMA/runs/<run-id>.json` | Run registry (PID, blueprint, args, ports). Used by `status`/`stop`/`restart`. Cleaned up when processes exit. |
| `~/.local/state/LIMA/logs/<run-id>/main.jsonl` | Structured logs (main process + all workers) |
| `.env` | Local config overrides (`LIMA_ROBOT_IP=192.168.123.161`) |
