# hairpin test, node2 send packets and receive them
# 均匀分布，不同发包侧core，不同flow number，不同pkt size，
# 事先下载好表项，仅测试转发性能
file=pkt_sendcir_mul_auto_sta3
lab=lab_afterin_rtt
lab_s=lab4
py_rule_gen="4_rule_gen.py"

line="bf3"
send_host="node2"
send_ip="10.15.198.161"
# recv_host="node1"
# recv_ip="10.15.198.160"
user="qyn"
password="nesc77qq"
run_path="/home/qyn/software/FastNIC/lab_new/${lab}"
bf3_run_path="/home/ubuntu/software/FastNIC/lab_new/${lab}"
arm_ip="10.15.198.164"

if [[ ! -d "${run_path}/lab_results/log" ]]
then
    mkdir -p ${run_path}/lab_results/log
fi
if [[ ! -d "${run_path}/lab_results/arm_log" ]]
then
    mkdir -p ${run_path}/lab_results/arm_log
fi

core_id="0"
pkt_len=-1
flow_size=-1
srcip_num=-1
dstip_num=-1
zipf_para=-1

off_thre=-1

# rcvdpdk_runtime=15 #second
senddpdk_runtime=5 #second
# test_time_rcv=$((rcvdpdk_runtime*2))
test_time_send=$((senddpdk_runtime*2))

flow_num_list=(100 10000 50000 100000)
cir_time_fn=${#flow_num_list[@]}

times=0
tmux_session=bf3_testpmd
for ((i=0; i<$cir_time_fn; i++))
do
    flow_num=${flow_num_list[$i]}

    #rule install in bf3
    ssh ubuntu@${arm_ip} "tmux new-session -d -s ${tmux_session}"

    ssh ubuntu@${arm_ip} "tmux send-keys -t ${tmux_session} 'cd ${bf3_run_path}/script/${lab_s}' C-m"
    ssh ubuntu@${arm_ip} "tmux send-keys -t ${tmux_session} 'rm rule_testpmd.txt' C-m"
    ssh ubuntu@${arm_ip} "tmux send-keys -t ${tmux_session} 'python3 ${py_rule_gen} ${flow_num}' C-m"
    sleep 10s
    ssh ubuntu@${arm_ip} "tmux send-keys -t ${tmux_session} 'sudo /opt/mellanox/dpdk/bin/dpdk-testpmd -l 0-3 -a 03:00.0  -- -i --rxq=4--txq=4 --hairpin=8' C-m"
    sleep 10s
    ssh ubuntu@${arm_ip} "tmux send-keys -t ${tmux_session} 'load ./rule_testpmd.txt' C-m"

    echo "  :waiting for rule install finish"
    while true; do
        output=$(ssh ubuntu@${arm_ip} "tmux capture-pane -p -t ${tmux_session}" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' | tail -n 3)
        if echo "$output" | grep -q "Read CLI commands from ./rule_testpmd.txt"; then
            break
        fi
        sleep 1
    done

    echo "  :finish flow rule install"
    send_run_para="flow_num $flow_num pkt_len $pkt_len flow_size $flow_size test_time $test_time_send srcip_num $srcip_num dstip_num $dstip_num zipf_para $zipf_para"
    # rcv_run_para="flow_num $flow_num pkt_len -1 flow_size $flow_size test_time $test_time_rcv srcip_num $srcip_num dstip_num $dstip_num zipf_para -1"

    # ssh -p 1022 $user@$recv_ip "cd ${run_path}/script && ./start_sta.sh $remotefile $line $recv_host 18-35 $run_path \"$rcv_run_para\"" >> ../lab_results/log/remote.out 2>&1 &
    # sleep 8s

    echo ../start_sta.sh $file $line $send_host $core_id $run_path \"$send_run_para\"
    ../start_sta.sh $file $line $send_host $core_id $run_path "$send_run_para"

    mkdir -p ${run_path}/lab_results/${file}/send_$times
    mv ${run_path}/lab_results/${file}/*.csv ${run_path}/lab_results/${file}/send_$times/
    # echo -e "off_thre,zipf_para\r\n${off_thre},${zipf_para}" > ${run_path}/lab_results/${file}/send_$times/para.csv

    # mkdir -p ${run_path}/lab_results/${remotefile}/rcv_$times
    # scp -P 1022 $user@$recv_ip:$run_path/lab_results/${remotefile}/*.csv $run_path/lab_results/${remotefile}/rcv_$times
    # ssh -p 1022 $user@$recv_ip "cd $run_path/lab_results/$remotefile && rm -f ./*.csv"

    # ovsfile_path="/home/ubuntu/software/FastNIC/lab_results/ovs_log"
    # mkdir -p ${run_path}/lab_results/ovslog/log_$times
    # scp ubuntu@${arm_ip}:$ovsfile_path/*.csv $run_path/lab_results/ovslog/log_$times
    # ssh ubuntu@${arm_ip} "cd $ovsfile_path && rm -f ./*.csv"
    ssh ubuntu@${arm_ip} "tmux send-keys -t ${tmux_session} 'quit' C-m"
    ssh ubuntu@${arm_ip} "tmux capture-pane -pS - -t ${tmux_session}" >> ${run_path}/lab_results/arm_log/bf3_arm_$times.out 2>&1
    ssh ubuntu@${arm_ip} "tmux kill-session -t ${tmux_session}"
    ((times++))
done



