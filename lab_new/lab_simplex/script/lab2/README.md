flow create 0 group 0 transfer pattern eth / end actions jump group 1 / end
flow create 0 group 1 transfer pattern eth / ipv4 src is 10.0.0.0 / tcp / end actions port_id id 1 / count / end

node2-node1, different number of flows
throughput

NIC: bf3
variable: flow_num, core num of ovs
app: ovs offload (in group 1) 