flow_num=5
# in bf3
# #run my app
# cd flow_create_nic_bf3/
# make clean && make
# sudo ./build/flow_create_nic_bf3 -l 0 -a 03:00.0,representor=[0,65535]
sed -i "s/rule_num =.*$/rule_num = ${flow_num}/" rule_gen.py
python3 rule_gen.py
sudo /opt/mellanox/dpdk/bin//dpdk-testpmd -l 0-3 -a 03:00.0,representor=[0,65535] -- -i
echo load rule_testpmd.txt

# #test command
# ## testpmd
# sudo /opt/mellanox/dpdk/bin//dpdk-testpmd -l 0-3 -a 03:00.0,representor=[0,65535] -- -i
# testpmd> flow create 0 group 0 transfer pattern eth / ipv4 src is 10.0.0.0 / tcp / end actions port_id id 1 / count / end
# ## send host (remote server)
# scapy >>> sendp(Ether(dst="00:11:22:33:44:55", src="a0:b1:c2:d3:e4:f5")/IP(dst="192.168.1.2", src="10.0.0.0")/TCP(dport=80, sport=12345)/Raw("0"*24), iface ="ens22np0")
# ## receive host
# sudo tcpdump -i ens22f0np0