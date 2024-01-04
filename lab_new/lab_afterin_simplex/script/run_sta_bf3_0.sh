# node2 send packets to node1
# 均匀分布，不同发包侧core，不同flow number，不同pkt size，
# 事先下载好表项，仅测试转发性能
file=pkt_send_mul_auto_sta6
remotefile=pkt_rcv_mul_auto_sta3
lab=lab_afterin_simplex

line="bf3"
send_host="node2"
recv_host="node1"
user="qyn"
run_path="/home/qyn/software/FastNIC/lab_new/${lab}"

if [[ ${line} == "bf3" ]]
then
    arm_ip="10.15.198.164"
fi

if [[ ${send_host} == "node2" ]]
then
    send_ip="10.15.198.161"
    recv_ip="10.15.198.160"
fi

if [[ ! -d "${run_path}/lab_results/log" ]]
then
    mkdir -p ${run_path}/lab_results/log
fi

core_id="0"
pkt_len=-1
flow_size=-1
srcip_num=-1
dstip_num=-1
zipf_para=-1

off_thre=-1

testpmd_runtime=20 #second
rcvdpdk_runtime=15 #second
senddpdk_runtime=5 #second
test_time_rcv=$((rcvdpdk_runtime*2))
test_time_send=$((senddpdk_runtime*2))

# flow_num_list=(100000 10000 100)
flow_num_list=(100 1000 5000 10000 20000 30000 40000 50000 60000 70000 80000 90000 100000)
cir_time_fn=${#flow_num_list[@]}

times=0
for ((i=0; i<$cir_time_fn; i++))
do
    flow_num=${flow_num_list[$i]}

    echo "expect bf3testmpd.expect $testpmd_runtime"
    expect bf3testmpd.expect $testpmd_runtime >> ../lab_results/log/bf3_testpmd.out 2>&1 &
    sleep 15s

    send_run_para="flow_num $flow_num pkt_len $pkt_len flow_size $flow_size test_time $test_time_send srcip_num $srcip_num dstip_num $dstip_num zipf_para $zipf_para"
    rcv_run_para="flow_num $flow_num pkt_len -1 flow_size $flow_size test_time $test_time_rcv srcip_num $srcip_num dstip_num $dstip_num zipf_para -1"

    echo "expect remote_run_sta_bf3.expect $run_path $user $password $remotefile $line \"$rcv_run_para\" >> ../lab_results/log/remote.out 2>&1 &"
    expect remote_run_sta_bf3.expect $run_path $user $password $remotefile $line "$rcv_run_para" >> ../lab_results/log/remote.out 2>&1 &
    sleep 8s

    echo ./start_sta.sh $file $line $send_host $core_id $run_path \"$send_run_para\"
    ./start_sta.sh $file $line $send_host $core_id $run_path "$send_run_para"
    sleep 30s

    mkdir -p ${run_path}/lab_results/${file}/send_$times
    mv ${run_path}/lab_results/${file}/*.csv ../lab_results/${file}/send_$times/
    # echo -e "off_thre,zipf_para\r\n${off_thre},${zipf_para}" > ${run_path}/lab_results/${file}/send_$times/para.csv

    mkdir -p ${run_path}/lab_results/${remotefile}/rcv_$times
    scp $user@$recv_ip:$run_path/lab_results/${remotefile}/*.csv $run_path/lab_results/${remotefile}/rcv_$times
    ssh $user@$recv_ip "cd $run_path/lab_results/$remotefile && rm -f ./*.csv"

    # ovsfile_path="/home/ubuntu/software/FastNIC/lab_results/ovs_log"
    # mkdir -p ${run_path}/lab_results/ovslog/log_$times
    # scp ubuntu@${arm_ip}:$ovsfile_path/*.csv $run_path/lab_results/ovslog/log_$times
    # ssh ubuntu@${arm_ip} "cd $ovsfile_path && rm -f ./*.csv"
    ((times++))
done

