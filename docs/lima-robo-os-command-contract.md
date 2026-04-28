# LIMA Robo OS — Command Contract

Every robotics command through LIMA Robo OS follows this contract:

| Field | Type | Description |
|-------|------|-------------|
| `command_id` | `string` | Unique command ID (UUID) |
| `source_user` | `string` | User or agent that initiated |
| `robot_id` | `string` | Target robot identifier |
| `environment` | `enum` | `replay` \| `simulation` \| `real_hardware` |
| `requested_action` | `string` | Natural language action description |
| `risk_level` | `enum` | `read_only` \| `low` \| `medium` \| `high` \| `blocked` |
| `approval_required` | `boolean` | Whether guardian approval is needed |
| `guardian_decision` | `string` | `approved` \| `denied` \| `pending` \| `N/A` |
| `mcp_tool_name` | `string` | Which MCP tool to call |
| `mcp_args` | `object` | Arguments for the MCP tool |
| `result` | `object` | Execution result from robot |
| `telemetry_snapshot` | `object` | Robot state at time of execution |
| `audit_timestamp` | `string` | ISO 8601 timestamp |

---

## Risk Classification

### `read_only`

Observing only — camera feed, map display, status check. No movement. **Always allowed.**

### `low`

Small movements in simulation — move 10cm, turn 15°. Safe in simulation.
Guardian logs but does not block.

### `medium`

Medium movements — move 1 meter, open gripper. **Requires human-in-loop approval before execution.**

### `high`

Large real-world movements — walk 2 meters, follow person, fly drone.
**Requires explicit approval + PIN + audit log.**

### `blocked`

Unknown commands, high-speed, unsafe without telemetry. Guardian blocks by default.
Logs attempted command.

---

## Emergency Stop

Always available. Bypasses all approval gates. Logs stop event immediately.

```
Emergency stop contract fields:
- command_id: <UUID>
- source_user: "LIMA Robo OS" (hardcoded, not user-supplied)
- robot_id: <target robot>
- environment: "real_hardware" (always)
- requested_action: "emergency_stop"
- risk_level: N/A (bypass)
- approval_required: false
- guardian_decision: "N/A"
- mcp_tool_name: "robot.stop"
- result: { "stopped": true, "timestamp": "<ISO8601>" }
- audit_timestamp: "<ISO8601>"
```

---

## Audit Requirements

Every command must be logged with:

- Full command contract
- Guardian decision
- Telemetry snapshot (robot pose, battery, sensors at execution time)
- Result or error

Audit log location: `~/.LIMA Robo OS/lima-audit/YYYY-MM-DD.jsonl`

Each line is a JSON object:

```json
{
  "command_id": "550e8400-e29b-41d4-a716-446655440000",
  "source_user": "phil",
  "robot_id": "unitree-go2-01",
  "environment": "simulation",
  "requested_action": "move forward 0.5 meters",
  "risk_level": "low",
  "approval_required": false,
  "guardian_decision": "N/A",
  "mcp_tool_name": "robot.move",
  "mcp_args": { "distance": 0.5, "direction": "forward" },
  "result": { "success": true, "new_pose": { "x": 0.5, "y": 0.0, "theta": 0.0 } },
  "telemetry_snapshot": { "battery": 0.85, "pose": { "x": 0.5, "y": 0.0, "theta": 0.0 }, "timestamp": "2026-04-24T17:00:00Z" },
  "audit_timestamp": "2026-04-24T17:00:00.123Z"
}
```

---

## Example Command Flow

**User:** "move forward 0.5 meters"

LIMA produces:

```json
{
  "command_id": "550e8400-e29b-41d4-a716-446655440000",
  "source_user": "phil",
  "robot_id": "unitree-go2-01",
  "environment": "simulation",
  "requested_action": "move forward 0.5 meters",
  "risk_level": "low",
  "approval_required": false,
  "guardian_decision": "N/A",
  "mcp_tool_name": "robot.move",
  "mcp_args": { "distance": 0.5, "direction": "forward" },
  "result": { "success": true },
  "telemetry_snapshot": { "battery": 0.85 },
  "audit_timestamp": "2026-04-24T17:00:00.123Z"
}
```

**Guardian decision:** `N/A` (LOW risk — no approval needed)

Result returned to LIMA Robo OS: `"Robot moved 0.5m forward. Battery: 85%."`