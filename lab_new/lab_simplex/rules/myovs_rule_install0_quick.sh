#add rules in_port=dpdk_p0,ip_src=$ip_dot,actions=output:dpdk_p0hpf
#rule number = O_CIRCLE_NUM * I_CIRCLE_NUM
ovsbr="ovsdpdk"

sudo /home/ubuntu/software/ovs_all/ovs_install/usr/bin/ovs-ofctl del-flows ${ovsbr}
echo "finish del former rules"

O_CIRCLE_NUM=10
I_CIRCLE_NUM=10000
for((i=0;i<$O_CIRCLE_NUM;i++));
do
  sudo /home/ubuntu/software/ovs_all/ovs_install/usr/bin/ovs-ofctl add-flows ${ovsbr} rules/rule_$i.txt
  echo "finish add $(($i*$I_CIRCLE_NUM)) - $((($i+1)*$I_CIRCLE_NUM-1))"
done