# LIMA Robotics Bridge

**LIMA** = Local Intelligent Machine Agent.

This package provides the Sparkbot-native robotics integration layer. It wraps DimOS
and exposes safe, audited robotics commands through MCP for Sparkbot agents.

## Status

**Early prototype.** Do not use with real hardware yet.

## Installation

(TBD — DimOS dependency required)

## Architecture

- **RoboticsBridge** — Main connector class for DimOS MCP server
- **RobotCommand** — Command data model (dataclass)
- **RobotCommandResult** — Execution result model (dataclass)
- **RiskLevel** — Risk classification enum (read_only | low | medium | high | blocked)

## Quick Start

```python
from lima.robotics_bridge import RoboticsBridge, RobotCommand, RiskLevel

bridge = RoboticsBridge(mcp_server_url="http://localhost:9990/mcp")

# List available MCP tools
tools = bridge.list_tools()

# Create and execute a command
cmd = RobotCommand(
    command_id="550e8400-e29b-41d4-a716-446655440000",
    source_user="phil",
    robot_id="unitree-go2-01",
    environment="simulation",
    requested_action="move forward 0.5 meters",
)
cmd.risk_level = bridge.classify_risk(cmd)

result = bridge.execute_mcp_tool(cmd)

# Emergency stop (always available)
stop_result = bridge.emergency_stop("unitree-go2-01")
```

## Safety

All commands are classified by risk level. Medium and High risk commands require
Guardian approval before execution. Emergency stop bypasses all gates.

## Audit

Every command is logged with full contract, telemetry snapshot, and result.
Audit logs stored in `~/.sparkbot/lima-audit/`.