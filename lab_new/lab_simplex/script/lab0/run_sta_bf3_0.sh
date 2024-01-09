# node2 send packets to node1
# 均匀分布，不同发包侧core，不同flow number，不同pkt size，
# 用pure ovs with offload
file=pkt_send_mul_auto_sta5_2
remotefile=pkt_rcv_mul_auto_sta3
lab=lab_simplex

line="bf3"
if [[ ${line} == "bf3" ]]
then
    arm_ip="10.15.198.164"
fi

send_host="node2"
recv_host="node1"
if [[ ${send_host} == "node2" ]]
then
    send_ip="10.15.198.161"
    recv_ip="10.15.198.160"
fi


user="qyn"
if [[ ${user} == "qyn" ]]
then
    run_path="/home/qyn/software/FastNIC/lab_new/${lab}"
    password="nesc77qq"
fi

if [[ ! -d "${run_path}/lab_results/log" ]]
then
    mkdir -p ${run_path}/lab_results/log
fi

#test1 in arm
# sudo ~/bin/bin/ovs-vsctl --no-wait set Open_vSwitch . other_config:hw-offload=true
# sudo ~/bin/scripts/ovs-ctl restart --system-id=random
# sudo ~/bin/bin/ovs-vsctl list open_vswitch #other_config

# /home/ubuntu/software/FastNIC/lab_new/lab_simplex/rules/myovs_rule_install0.sh
# or
# /home/ubuntu/software/FastNIC/lab_new/lab_simplex/rules/myovs_rule_install0_quick.sh.sh

#test1 in arm 
# sudo ~/bin/bin/ovs-vsctl --no-wait set Open_vSwitch . other_config:hw-offload=false
# sudo ~/bin/scripts/ovs-ctl restart --system-id=random
# sudo ~/bin/bin/ovs-vsctl list open_vswitch #other_config

# /home/ubuntu/software/FastNIC/lab_new/lab_simplex/rules/myovs_rule_install0_quick.sh.sh

core_id="0"
pkt_len=-1
flow_size=-1
srcip_num=-1
dstip_num=-1
zipf_para=-1

off_thre=-1

test_time_rcv=30
test_time_send=10

# flow_num_list=(100 10)
flow_num_list=(100 10000 50000 100000)
cir_time_fn=${#flow_num_list[@]}

times=0
for ((i=0; i<$cir_time_fn; i++))
do
    flow_num=${flow_num_list[$i]}

    # echo "expect remote_bf2_config.expect $off_thre"
    # expect remote_bf2_config.expect $off_thre

    send_run_para="flow_num $flow_num pkt_len $pkt_len flow_size $flow_size test_time $test_time_send srcip_num $srcip_num dstip_num $dstip_num zipf_para $zipf_para"
    rcv_run_para="flow_num $flow_num pkt_len -1 flow_size $flow_size test_time $test_time_rcv srcip_num $srcip_num dstip_num $dstip_num zipf_para -1"

    echo start rcv
    echo "expect remote_run_sta_bf3.expect $run_path $user $password $remotefile $line \"$rcv_run_para\" >> ${run_path}/lab_results/log/remote.out 2>&1 &"
    echo -e "\n"
    expect remote_run_sta_bf3.expect $run_path $user $password $remotefile $line "$rcv_run_para" >> ${run_path}/lab_results/log/remote.out 2>&1 &
    sleep 8s

    echo start send
    echo ../start_sta.sh $file $line $send_host $core_id $run_path \"$send_run_para\"
    ../start_sta.sh $file $line $send_host $core_id $run_path "$send_run_para"
    sleep 30s

    mkdir -p ${run_path}/lab_results/${file}/send_$times
    mv ${run_path}/lab_results/${file}/*.csv ${run_path}/lab_results/${file}/send_$times/
    echo -e "off_thre,zipf_para\r\n${off_thre},${zipf_para}" > ${run_path}/lab_results/${file}/send_$times/para.csv

    mkdir -p ${run_path}/lab_results/${remotefile}/rcv_$times
    scp -P 1022 $user@$recv_ip:$run_path/lab_results/${remotefile}/*.csv $run_path/lab_results/${remotefile}/rcv_$times
    ssh -p 1022 $user@$recv_ip "cd $run_path/lab_results/$remotefile && rm -f ./*.csv"

    ovsfile_path="/home/ubuntu/software/FastNIC/lab_results/ovs_log"
    mkdir -p ${run_path}/lab_results/ovslog/log_$times
    scp ubuntu@${arm_ip}:$ovsfile_path/*.csv $run_path/lab_results/ovslog/log_$times
    ssh ubuntu@${arm_ip} "cd $ovsfile_path && rm -f ./*.csv"

    echo -e "test ${times} finish"
    echo -e "\n"
    ((times++))
done

