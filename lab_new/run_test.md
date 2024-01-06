# test without auto script
## lab afterin_simplex

```
## testpmd
sudo /opt/mellanox/dpdk/bin/dpdk-testpmd -l 0-3 -a 03:00.0,representor=[0,65535] -- -i
testpmd> flow create 0 group 0 transfer pattern eth / ipv4 src is 10.0.0.0 / tcp / end actions port_id id 1 / count / end
## send host (remote server)
scapy >>> sendp(Ether(dst="00:11:22:33:44:55", src="a0:b1:c2:d3:e4:f5")/IP(dst="192.168.1.2", src="10.0.0.0")/TCP(dport=80, sport=12345)/Raw("0"*24), iface ="ens22np0")
## receive host
sudo tcpdump -i ens22f0np0
```

## lab afterin_rtt
```
## testpmd
sudo /opt/mellanox/dpdk/bin/dpdk-testpmd -l 0-3 -a 03:00.0  -- -i --rxq=4--txq=4 --hairpin=8
testpmd> flow create 0 group 0 ingress pattern eth / ipv4 src is 10.0.0.0 / tcp / end actions set_ipv4_dst ipv4_addr 2.2.2.2 / queue index 5 / count / end
## send server
scapy >>> sendp(Ether(dst="00:11:22:33:44:55", src="a0:b1:c2:d3:e4:f5")/IP(dst="192.168.1.2", src="10.0.0.0")/TCP(dport=80, sport=12345)/Raw("0"*24), iface ="ens22np0")
sudo tcpdump -i ens22np0
```