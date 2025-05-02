# Script: OSPF Latency-Based Cost Adjuster
# Copyright (C) 2025  asvdvl; GNU GPL v3
# Description: Dynamically adjusts OSPF interface cost based on average ping latency to neighbors.
# Requirements: RouterOS v7+, OSPF with interface-templates, configured interface list
# https://github.com/asvdvl/mikrotik-scripts/blob/main/ospf-latensy-cost-autocalc.rsc
# Also check linux version in `ospf-latensy-cost-autocalc - linux/ospf-latensy-cost-autocalc.py`

:local sourceList "ospf-latensy-cost-push"
#:local overrides {"ifName"={"multiplier"=1,"deadband"=2}} #not implemented

# ospf instance name from where neighbors' ip will be fraternized.
#  for now this does not limit the interface update from other instances,
#  be careful
:local validInstance "v4"

# threshold for cost update
# the deadband value and costMultiplier value work for me in a simple way, base_deadband(5) * your costMultiplier = deadband.
#  the multiplier itself is needed if you have several devices and you need to
#  prioritize the paths of one over the paths of another,
#  if you have a group of links that require a different multiplier,
#  then you can set different values for each interface below in overrides
:local deadband 5
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
            
            :if (($neighborIP in $net) && $neighborInstance = $validInstance) do={
                :log info "iface=$iface NeighborIP=$neighborIP NeighborID=$([/routing/ospf/neighbor get $neighbor router-id])"

                :local pingResult [/tool/ping address=$neighborIP count=$pingCount size=1000 interval=$timeout as-value]
                
                :local avg 0
                :foreach try in=$pingResult do={
                    if ([:len ($try->"status")] > 0) do={
                        # the idea is not to spoil the results because of 1-2 lost packets but at the same time to reduce the value of the link
                        :set avg ($avg + ($avg*2))
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

                    if ($diff > $deadband) do={
                        /routing/ospf/interface-template/set $template cost=$newCost
                    } else={
                        :log info "value in range of deadband. current: $currentCost. diff from calculated: $diff. in +- of $deadband"
                    }
                }
            }
        }
    }
    :put ""
}
