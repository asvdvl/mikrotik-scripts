#!/usr/bin/env python3

import subprocess, json, time
from ping3 import ping

interfaceList = [
    "wg-ar1",
    "wg-ar2",
    "wg-ur2b",
    "wg-ur2"
]

overrides = {
    "wg-ar1": {"multiplier": 5, "deadband": 25},
}

deadband = 10
costMultiplier = 2
timeout = 0.5
alsoUpdateIPv6OnSameIface = True
pingCount = 25
writeChanges = False # saves changes to disc

def run_vtysh_command(cmd):
    args = ['vtysh', '-c']
    if isinstance(cmd, str):
        args.append(cmd)
    else:
        args.extend(cmd)

    result = subprocess.run(args, capture_output=True, text=True)
    return result.stdout.strip()

def run_vtysh_json(cmd):
    return json.loads(run_vtysh_command(cmd + " json"))

neirbors = run_vtysh_json('show ip ospf neighbor')["neighbors"]

for neikey in neirbors:
    nei = neirbors[neikey][0]
    ifdata = nei["ifaceName"].split(":")

    iface = ifdata[0]
    if not iface in interfaceList:
        continue

    neighborIP = nei["ifaceAddress"]

    print(f"iface={iface} NeighborIP={neighborIP} NeighborID={neikey}")
    
    responses = []
    for _ in range(pingCount):
        rtt = ping(neighborIP, timeout=timeout)
        responses.append(rtt)

    loss = 0

    def get_avg(array):
        return sum(array) / len(array) if array else 0

    def reg_loss():
        global loss, timeout
        loss = loss + 1

        # the idea is not to spoil the results because of 1-2 lost packets but at the same time to reduce the value of the link
        return get_avg(responses)*2 or timeout 

    success = [r if r is not False else reg_loss() for r in responses]
    avg = get_avg(success) * 1000

    if iface in overrides and 'multiplier' in overrides[iface]:
        newCost = int(avg * overrides[iface]["multiplier"])
    else:
        newCost = int(avg * costMultiplier)

    ifaceObj = run_vtysh_json('show ip ospf interface')["interfaces"][iface]
    currCost = ifaceObj["cost"]
    print(f"new cost {newCost}, current:{currCost}, avg {avg:.2f}, loss:{loss}")

    diff = abs(currCost - newCost)
    if (diff > deadband):
        run_vtysh_command(["configure terminal",
            "-c", f"interface {iface}",
            "-c", f"ip ospf cost {newCost}",
            "-c", "end",
            "-c", "write"
        ])
        print("update cost")
    else:
        print(f"value in range of deadband. diff from calculated: {diff}. in +- of {deadband}")

    print()