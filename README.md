## OSPF Latency-Based Cost Adjuster (ospf-latensy-cost-autocalc.rsc)

This MikroTik RouterOS script automatically updates the OSPF interface cost based on measured network latency (ping) to OSPF neighbors.

### Purpose

The script measures the average round-trip time (RTT) to OSPF neighbors over a specified list of interfaces and adjusts the `cost` value of the corresponding `interface-template` if the change exceeds a defined threshold (deadband). This allows routing decisions to dynamically adapt to link quality.

### Main Parameters

- `sourceList` — name of the interface list to monitor
- `validInstance` — name of the OSPF instance to filter (e.g., `v4`)
- `deadband` — minimum cost change required to trigger an update
- `costMultiplier` — multiplier to convert latency into cost
- `timeout` — interval between ping requests (in seconds)

### How It Works

1. Retrieves interfaces from `sourceList`
2. For each interface and its IP address:
   - Finds OSPF neighbors in the same subnet
   - Measures latency using `ping`
   - Calculates a new cost value
   - Compares it with the current cost and updates if needed

### Requirements

- MikroTik RouterOS v7+
- OSPF must be configured using `interface-template`
