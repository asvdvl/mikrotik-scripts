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

### Installation

1. MikroTik
   - Open MikroTik Terminal
   - Download and install the script:
   ```
   :global result [/tool fetch url="https://raw.githubusercontent.com/asvdvl/mikrotik-scripts/refs/heads/main/ospf-latensy-cost-autocalc.rsc" as-value output=user]
   :global scriptText ($result->"data")
   /system script add name="ospf cost adjustment by delay" source=$scriptText
   ```
   - Setup sheduler
   - `/system scheduler add interval=10m name=schedule1 on-event="/system/script/run \"ospf cost adjustment by delay\"" policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon` # policy is temporary

