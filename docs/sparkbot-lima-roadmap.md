# Sparkbot LIMA — Robotics Integration Roadmap

## What is LIMA?

- **LIMA** = Local Intelligent Machine Agent
- **Product:** Sparkbot LIMA — "Give Sparkbot a body"
- LIMA is the Sparkbot-native robotics runtime

LIMA bridges Sparkbot's conversational AI to real-world robotics. It wraps DimOS
with safety gates, audit logging, and Sparkbot-native APIs so users can command
robots through natural language.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Sparkbot (Operator)                       │
│                    chat / CLI / API interface                     │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Sparkbot Robotics API                           │
│           /api/v1/robotics/status, command, tools                 │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    LIMA Robotics Bridge                           │
│    - Risk classification (read_only → blocked)                   │
│    - Guardian approval gates                                      │
│    - Audit logging                                               │
│    - MCP client → DimOS                                          │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                  DimOS MCP Server                                 │
│                  (existing DimOS runtime)                        │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              Robot Blueprint / Skills                             │
│              Unitree Go2 (simulation or real)                    │
└─────────────────────────────────────────────────────────────────┘
```

### DimOS Integration Layer

- **LIMA acts as Sparkbot's interface to DimOS.** Sparkbot talks to LIMA; LIMA
  talks to DimOS and robots.
- **LIMA does NOT replace DimOS.** It wraps DimOS for Sparkbot — adds safety,
  auditability, and natural-language interpretation on top of existing MCP tools.
- LIMA translates Sparkbot commands into MCP tool calls and formats responses
  for conversational UI.

---

## First Target

**Command:** `dimos --simulation run unitree-go2-agentic-mcp`

This runs a Unitree Go2 robot in simulation with an MCP agentic layer. The goal
is to prove end-to-end command flow from Sparkbot natural language to robot
execution and telemetry back.

### Sparkbot Commands to Prove

| Command | Expected Behavior |
|---------|-------------------|
| "move forward 0.5 meters" | Robot moves 0.5m forward in simulation |
| "turn left" | Robot rotates 90° left |
| "stop" | Robot halts immediately |
| "describe camera feed" | Returns camera description / frame data |
| "explore the room" | Robot navigates and maps environment |

### Acceptance Test

Sparkbot sends a command via MCP → DimOS executes → robot status/logs returned
to Sparkbot. Result includes telemetry snapshot and audit entry.

---

## Safety Model

| Rule | Implementation |
|------|----------------|
| Read-only commands always allowed | risk_level=read_only → auto-approve |
| Low-risk simulation movement allowed | risk_level=low → log only, no block |
| Real hardware movement requires Guardian approval | risk_level=medium/high → guardian gate |
| Emergency stop always available | Bypasses all gates, logs immediately |
| Every command audited | Full contract + result + telemetry logged |

---

## Phases

### Phase 0 — Repository Audit

Audit existing sparkdimos structure. Identify MCP endpoints, DimOS capabilities,
robot blueprints, simulation configuration. Map the full DimOS tool surface.

**Deliverables:**
- `docs/architecture.md` — DimOS internals map
- `docs/mcp-endpoints.md` — MCP tool inventory
- `docs/robot-blueprints.md` — supported robots and their capabilities

### Phase 1 — Simulation MCP Proof

Run `dimos --simulation run unitree-go2-agentic-mcp`. Verify:
- MCP server starts on expected port (default 9990)
- Tools are listable via MCP protocol
- Commands execute and return telemetry

**Deliverables:**
- Working simulation loop
- Sparkbot can send commands and receive robot state
- Audit trail visible in logs

### Phase 2 — Sparkbot API Bridge

Build Sparkbot-side robotics connector with endpoints:

| Endpoint | Purpose |
|----------|---------|
| `GET /api/v1/robotics/status` | Robot and bridge status |
| `GET /api/v1/robotics/tools` | Available MCP tools |
| `POST /api/v1/robotics/command` | Execute a command |
| `POST /api/v1/robotics/emergency-stop` | Immediate halt |

**Deliverables:**
- REST API registered with Sparkbot
- `RobotCommand` contract enforced
- Risk classification applied to every command

### Phase 3 — Guardian Approval Gates

Implement approval workflow:

- **LOW risk** → run immediately, log only
- **MEDIUM risk** → pause, request human-in-loop approval
- **HIGH risk** → require explicit approval + PIN + audit entry
- **BLOCKED** → reject, log attempted command
- **Unknown commands** → blocked by default

Guardian can approve via:
- Sparkbot chat confirmation
- Dashboard button
- Breakglass procedure for emergencies

**Deliverables:**
- Guardian approval UI/widget
- PIN-protected breakglass
- Full audit trail in `~/.sparkbot/lima-audit/`

### Phase 4 — Real Hardware Adapter

After simulation proves out, add real Unitree Go2 hardware support:

- Serial / network connection to Go2
- Real-time telemetry ingestion
- Safety limits for physical movement
- Fallback to simulation if hardware disconnects

**Deliverables:**
- `lima/adapters/unitree_go2.py` hardware adapter
- Hardware test checklist
- Emergency stop verified on real hardware

### Phase 5 — Dashboard / Workstation UI

Add Sparkbot UI for robotics monitoring and control:

- Live robot telemetry panel
- Command history and audit viewer
- Map / camera feed display
- Guardian approval queue
- Emergency stop button (always visible)

**Deliverables:**
- `sparkbot-ui/robotics/` module
- Web dashboard or terminal UI
- Mobile companion (optional)

---

## Success Metrics

- [ ] Phase 0: DimOS tool surface fully documented
- [ ] Phase 1: End-to-end command roundtrip in simulation (< 2s latency)
- [ ] Phase 2: All 4 API endpoints functional and tested
- [ ] Phase 3: Guardian gates block unauthorized commands
- [ ] Phase 4: Real Go2 responds to commands
- [ ] Phase 5: Dashboard shows live telemetry and audit trail