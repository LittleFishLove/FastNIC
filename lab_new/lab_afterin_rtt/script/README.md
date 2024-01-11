lab0:
    node2-bf3-node2 (hairpin), different number of flows
    throughput + rtt

    NIC: bf3
    variable: flow_num group=0
    app: testpmd, download rule first 

lab1:
    node2-bf3-node2 (hairpin), different number of flows
    throughput + rtt

    NIC: bf3
    variable: flow_num group=1
    app: testpmd, download rule first 

lab3:
    node2-bf3-node2 (hairpin), different number of flows
    throughput + rtt + pkt_seq

    NIC: bf3
    variable: flow_num group=0
    app: testpmd, download rule first 

lab4:
    node2-bf3-node2 (hairpin), different number of flows
    throughput + rtt + pkt_seq

    NIC: bf3
    variable: flow_num group=1
    app: testpmd, download rule first 