# node2 send packets to node1
# 均匀分布，不同发包侧core，不同flow number，不同pkt size，
# 事先下载好表项，仅测试转发性能
file=pkt_send_mul_auto_sta6
remotefile=pkt_rcv_mul_auto_sta3
lab=lab_afterin_simplex
py_rule_gen="0_rule_gen.py"

line="bf3"
send_host="node2"
recv_host="node1"
user="qyn"
password="nesc77qq"
run_path="/home/qyn/software/FastNIC/lab_new/${lab}"
bf3_run_path="/home/ubuntu/software/FastNIC/lab_new/${lab}"

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

flow_num_list=(100 1000 5000 10000 20000 30000 40000 50000 60000 70000 80000 90000 100000)
cir_time_fn=${#flow_num_list[@]}

times=0
tmux_session=bf3_testpmd
for ((i=0; i<$cir_time_fn; i++))
do
    flow_num=${flow_num_list[$i]}

    #rule install in bf3
    ssh ubuntu@${arm_ip} "tmux new-session -d -s ${tmux_session}"

    ssh ubuntu@${arm_ip} "tmux send-keys -t ${tmux_session} 'cd ${bf3_run_path}/script' C-m"
    ssh ubuntu@${arm_ip} "tmux send-keys -t ${tmux_session} 'rm rule_testpmd.txt' C-m"
    ssh ubuntu@${arm_ip} "tmux send-keys -t ${tmux_session} 'python3 ${py_rule_gen} ${flow_num}' C-m"
    ssh ubuntu@${arm_ip} "tmux send-keys -t ${tmux_session} 'sudo /opt/mellanox/dpdk/bin/dpdk-testpmd -l 0-1 -a 03:00.0,representor=\[0,65535\] -- -i' C-m"
    ssh ubuntu@${arm_ip} "tmux send-keys -t ${tmux_session} 'load ./rule_testpmd.txt' C-m"

    while true; do
        output=$(ssh ubuntu@${arm_ip} "tmux capture-pane -p -t ${tmux_session}" | tail -n 3)
        if echo "$output" | grep -q "Read CLI commands from ./rule_testpmd.txt"; then
            break
        fi
        sleep 1
    done

    echo "  :finish flow rule install"

    send_run_para="flow_num $flow_num pkt_len $pkt_len flow_size $flow_size test_time $test_time_send srcip_num $srcip_num dstip_num $dstip_num zipf_para $zipf_para"
    rcv_run_para="flow_num $flow_num pkt_len -1 flow_size $flow_size test_time $test_time_rcv srcip_num $srcip_num dstip_num $dstip_num zipf_para -1"

    # echo "expect remote_run_sta_bf3.expect $run_path $user $password $remotefile $line \"$rcv_run_para\" >> ../lab_results/log/remote.out 2>&1 &"
    # echo -e "\n"
    # expect remote_run_sta_bf3.expect $run_path $user $password $remotefile $line "$rcv_run_para" >> ../lab_results/log/remote.out 2>&1 &
    ssh -p 1022 $user@$recv_ip "cd ${run_path}/script && ./start_sta.sh $remotefile $line $recv_host 18-35 $run_path \"rcv_run_para\""
    sleep 8s

    echo ./start_sta.sh $file $line $send_host $core_id $run_path \"$send_run_para\"
    ./start_sta.sh $file $line $send_host $core_id $run_path "$send_run_para"
    sleep 30s

    mkdir -p ${run_path}/lab_results/${file}/send_$times
    mv ${run_path}/lab_results/${file}/*.csv ../lab_results/${file}/send_$times/
    # echo -e "off_thre,zipf_para\r\n${off_thre},${zipf_para}" > ${run_path}/lab_results/${file}/send_$times/para.csv

    mkdir -p ${run_path}/lab_results/${remotefile}/rcv_$times
    scp -P 1022 $user@$recv_ip:$run_path/lab_results/${remotefile}/*.csv $run_path/lab_results/${remotefile}/rcv_$times
    ssh -p 1022 $user@$recv_ip "cd $run_path/lab_results/$remotefile && rm -f ./*.csv"

    # ovsfile_path="/home/ubuntu/software/FastNIC/lab_results/ovs_log"
    # mkdir -p ${run_path}/lab_results/ovslog/log_$times
    # scp ubuntu@${arm_ip}:$ovsfile_path/*.csv $run_path/lab_results/ovslog/log_$times
    # ssh ubuntu@${arm_ip} "cd $ovsfile_path && rm -f ./*.csv"
    ssh ubuntu@${arm_ip} "tmux send-keys -t ${tmux_session} 'quit' C-m"

    ssh ubuntu@${arm_ip} "tmux kill-session -t ${tmux_session}"
    ((times++))
done



