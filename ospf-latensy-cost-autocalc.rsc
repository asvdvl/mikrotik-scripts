# Script: OSPF Latency-Based Cost Adjuster
# Copyright (C) 2025  asvdvl; GNU GPL v3
# Description: Dynamically adjusts OSPF interface cost based on average ping latency to neighbors.
# Requirements: RouterOS v7+, OSPF with interface-templates, configured interface list


:local sourceList "ospf-latensy-cost-push"
:local validInstance "v4"

# threshold for cost update
:local deadband 10
:local costMultiplier 2
:local timeout "0.5"

:foreach i in=[/interface/list/member find where list=$sourceList] do={
    :global iface [/interface/list/member get $i interface]
    :put $iface

    :foreach addrObj in=[/ip/address/find interface=$iface] do={
    :global addr [/ip/address/get $addrObj address]
    :global net "$([/ip/address/get $addrObj network])$(:put [:pick $addr [:find $addr "/" -1] [:len $addr]])"
    :set addr [:pick $addr 0 [:find $addr "/" -1]]
    :put "addr $addr"
    :put "net $net"

    :foreach neighbor in [/routing/ospf/neighbor find] do={
        :global neighborIP [/routing/ospf/neighbor get $neighbor address]
        :global neighborInstance [/routing/ospf/neighbor get $neighbor instance]
        
        :if (($neighborIP in $net) && $neighborInstance = $validInstance) do={
        :put ("Neighbor IP: $neighborIP")
        :global pingResult [/tool/ping address=$neighborIP count=4 size=1000 interval=$timeout as-value]
        
        :global avg 0
        :foreach try in=$pingResult do={
            if ([:len ($try->"status")] > 0) do={
                :set avg ($avg + $timeout)
            } else={
                :set avg ($avg + ($try->"time"))
            }
        }
        :set avg ($avg / [:len $pingResult])
        :local hours [:tonum [:pick $avg 0 2]]
        :local minutes [:tonum [:pick $avg 3 5]]
        :local seconds [:tonum [:pick $avg 6 8]]
        :global newCost ((($hours*3600) + ($minutes * 60) + ($seconds) + [:pick $avg 9 12]) * $costMultiplier)
        :put "new cost $newCost, avg $avg"
        
        :foreach template in=[/routing/ospf/interface-template/find interfaces=$iface] do={
            :global currentCost [/routing/ospf/interface-template/get $template cost]
            :global diff ($currentCost - $newCost)
            :if ($diff < 0) do={ :set $diff (-1 * $diff) }

            if ($diff > $deadband) do={
                /routing/ospf/interface-template/set $template cost=$newCost
            }
        }
        }
    }
    
    }

    :put ""
}