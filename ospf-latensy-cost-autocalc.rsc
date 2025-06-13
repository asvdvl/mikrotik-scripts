# Script: OSPF Latency-Based Cost Adjuster
# Copyright (C) 2025  asvdvl; GNU GPL v3
# Description: Dynamically adjusts OSPF interface cost based on average ping latency to neighbors.
# Requirements: RouterOS v7+, OSPF with interface-templates, configured interface list
# https://github.com/asvdvl/mikrotik-scripts/blob/main/ospf-latensy-cost-autocalc.rsc
# Also check linux version in `ospf-latensy-cost-autocalc - linux/ospf-latensy-cost-autocalc.py`

:local sourceList "ospf-latensy-cost-push"
:local overrides {"ifName"={"multiplier"=1; "deadband"=10}}

# ospf instance name from where neighbors' ip will be fraternized.
#  for now this does not limit the interface update from other instances,
#  be careful
:local validInstance "v4"

# threshold % for cost update
# The % deadband multiplier itself is needed if you have multiple devices
#  and you need to prioritize the paths of one over the paths of another,
#  if you have a group of links that need a different multiplier, then you
#  can set different values ​​for each interface above in the overrides. 
#  The value is specified in %, by default 20%.
:local deadband 20
:local costMultiplier 1

:local timeout "0.5"

#25 is a bit much, but it should be accurate.
:local pingCount 25

:foreach i in=[/interface/list/member find where list=$sourceList] do={
    :local iface [/interface/list/member get $i interface]

    :foreach addrObj in=[/ip/address/find interface=$iface] do={
        :local addr [/ip/address/get $addrObj address]
        :local net "$([/ip/address/get $addrObj network])$(:put [:pick $addr [:find $addr "/" -1] [:len $addr]])"
        :set addr [:pick $addr 0 [:find $addr "/" -1]]

        :foreach neighbor in [/routing/ospf/neighbor find] do={
            :local neighborIP [/routing/ospf/neighbor get $neighbor address]
            :local neighborInstance [/routing/ospf/neighbor get $neighbor instance]
            :local currDeadband 1
            :local currCostMultiplier 1

            :if (($neighborIP in $net) && $neighborInstance = $validInstance) do={
                if ([:typeof ($overrides->$iface)] != "nothing") do={
                    :global overridedata ($overrides->$iface)

                    :set currDeadband ($overridedata->"deadband")
                    :set currCostMultiplier ($overridedata->"multiplier")
                } else={
                    :set currDeadband $deadband
                    :set currCostMultiplier $costMultiplier
                }

                :log info "iface=$iface net=$net NeighborIP=$neighborIP currDeadband=$currDeadband% currCostMultiplier=$currCostMultiplier"

                :local pingResult [/tool/ping address=$neighborIP count=$pingCount size=1000 interval=$timeout as-value]
                
                :local avg 0
                :foreach try in=$pingResult do={
                    if ([:len ($try->"status")] > 0) do={
                        :set avg ($avg + ($avg / [:len $pingResult])*2)
                    } else={
                        :set avg ($avg + ($try->"time"))
                    }
                }
                :set avg ($avg / [:len $pingResult])
                :local hours [:tonum [:pick $avg 0 2]]
                :local minutes [:tonum [:pick $avg 3 5]]
                :local seconds [:tonum [:pick $avg 6 8]]
                :local newCost ((($hours*3600) + ($minutes * 60) + ($seconds) + [:pick $avg 9 12]) * $costMultiplier)

                :log info "new cost $newCost, avg $avg"
                
                :foreach template in=[/routing/ospf/interface-template/find interfaces=$iface] do={
                    :local currentCost [/routing/ospf/interface-template/get $template cost]
                    :local diff ($currentCost - $newCost)
                    :if ($diff < 0) do={ :set $diff (-1 * $diff) }
                    :local divergence ($currentCost*$currDeadband/100)

                    if ($diff > $divergence) do={
                        /routing/ospf/interface-template/set $template cost=$newCost
                    } else={
                        :log info "value in range of deadband. current: $currentCost. diff from calculated: $diff. in +- of $divergence"
                    }
                }
            }
        }
    }
}
