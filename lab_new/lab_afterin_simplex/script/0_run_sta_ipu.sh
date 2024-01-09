#!/bin/bash
# node2 send packets to node1
# 均匀分布，不同发包侧core，不同flow number，不同pkt size，
# 事先下载好表项，仅测试转发性能
file=pkt_send_mul_auto_sta6 #send app
lab=lab_afterin_simplex

line="186-171"
# send_host="rdma2-server"
send_host="186_ali"
send_ip="22.22.22.186"
# recv_host="ipuserver"
recv_host="171_ali"
recv_ip="22.22.22.171"
user="root"
run_path="/root/qyn/FastNIC/lab_new/${lab}"
ipu_run_path="/root/LAB_code/FastNIC/lab_new/${lab}"

if [[ ! -d "${run_path}/lab_results/log" ]]
then
    mkdir -p ${run_path}/lab_results/log
fi
if [[ ! -d "${run_path}/lab_results/rcv" ]]
then
    mkdir -p ${run_path}/lab_results/rcv
fi
if [[ ! -d "${run_path}/lab_results/ipu_log" ]]
then
    mkdir -p ${run_path}/lab_results/ipu_log
fi

core_id="0"
pkt_len=-1
flow_size=-1
srcip_num=-1
dstip_num=-1
zipf_para=-1

off_thre=-1

rcvdpdk_runtime=15 #second
senddpdk_runtime=5 #second
test_time_send=$((senddpdk_runtime*2))

flow_num_list=(5)
# flow_num_list=(100 1000 5000 10000 20000 30000 40000 50000 60000 70000 80000 90000 100000)
cir_time_fn=${#flow_num_list[@]}

times=0
rcv_tmux=rcv_testpmd
ipu_tmux=ipu_testpmd

for ((i=0; i<$cir_time_fn; i++))
do
    flow_num=${flow_num_list[$i]}

    #rcv app start
    tmux new-session -d -s ${rcv_tmux}
    tmux send-keys -t ${rcv_tmux} "dpdk-devbind.py -b vfio-pci e4:00.0" Enter
    tmux send-keys -t ${rcv_tmux} "dpdk-devbind.py -b vfio-pci e4:00.1" Enter
    tmux send-keys -t ${rcv_tmux} "dpdk-devbind.py -s" Enter
    tmux send-keys -t ${rcv_tmux} "/root/qyn/hobbit-dpdk/build/app/dpdk-testpmd --lcores 0-7 -a \"e4:00.0,vport=[0]\" -a \"e4:00.1,vport=[1]\" -- -i" Enter
    sleep 10s
    echo "  start rcv"

    #ipu acc install rules
    rm -f ${run_path}/script/ipu_run.sh
    echo tmux send-keys -t ${ipu_tmux} \"cd /root/LAB_code/hobbit-dpdk/app/hobbit-rule\" Enter > ${run_path}/script/ipu_run.sh
    echo tmux send-keys -t ${ipu_tmux} \"sed -i \'s/#define FLOW_NUM.*$/#define FLOW_NUM ${flow_num}/\' hobbit_rte_rule.h\" Enter >> ${run_path}/script/ipu_run.sh
    echo tmux send-keys -t ${ipu_tmux} \"cd /root/LAB_code/hobbit-dpdk\" Enter >> ${run_path}/script/ipu_run.sh
    echo tmux send-keys -t ${ipu_tmux} \"ninja -C build\" Enter >> ${run_path}/script/ipu_run.sh
    echo tmux send-keys -t ${ipu_tmux} \"/root/LAB_code/hobbit-dpdk/build/app/dpdk-hobbit-rule -c 0xf -s 0x8 --in-memory -a 00:01.6,vport=[0-1],representor=vf[0-3],flow_parser=\'/root/em_fastpath.json\' -- -i\" Enter >> ipu_run.sh
    ssh root@22.22.22.173 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@100.0.0.100 ssh root@192.168.0.2 tmux new-session -d -s ${ipu_tmux}
    scp -J root@22.22.22.173,root@100.0.0.100 ipu_run.sh root@192.168.0.2:${ipu_run_path}/script
    ssh root@22.22.22.173 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@100.0.0.100 ssh root@192.168.0.2 chmod +x ${ipu_run_path}/script/ipu_run.sh
    ssh root@22.22.22.173 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@100.0.0.100 ssh root@192.168.0.2 ${ipu_run_path}/script/ipu_run.sh

    #do not start send app until install finish 
    echo waiting rule install finish
    flow_end=$((flow_num-1))
    while true; do
        output=$(ssh root@22.22.22.173 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@100.0.0.100 ssh root@192.168.0.2 "tmux capture-pane -p -t ${ipu_tmux}" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' | tail -n 3)
        if echo "$output" | grep -q "Flow rule #${flow_end} created"; then
            break
        fi
        sleep 1
    done

    #send app start
    echo send app start 
    echo send start time:
    date +%s

    send_run_para="flow_num $flow_num pkt_len $pkt_len flow_size $flow_size test_time $test_time_send srcip_num $srcip_num dstip_num $dstip_num zipf_para $zipf_para"
    echo ./start_sta.sh $file $line $send_host $core_id $run_path \"$send_run_para\"
    ssh ${user}@${send_ip} "$run_path/script/start_sta.sh $file $line $send_host $core_id $run_path \"$send_run_para\"" >> $run_path/lab_results/${file}/send_${times}.out 2>&1 &

    #output rcv info per second
    echo rcv start time:
    date +%s
    for ((j=0; j<$rcvdpdk_runtime; j++)) 
    do 
        sleep 1s
        tmux send-keys -t ${rcv_tmux} "show port stats all" Enter
    done

    sudo mkdir -p ${run_path}/lab_results/${file}/send_$times
    scp $user@$send_ip:$run_path/lab_results/${file}/*.csv $run_path/lab_results/${file}/send_$times
    ssh $user@$send_ip "cd $run_path/lab_results/$file && rm -f ./*.csv"
    # echo -e "off_thre,zipf_para\r\n${off_thre},${zipf_para}" > ${run_path}/lab_results/${file}/send_$times/para.csv
    
    tmux send-keys -t ${rcv_tmux} 'quit' C-m
    tmux capture-pane -pS - -t ${rcv_tmux} >> ${run_path}/lab_results/rcv/rcvtestpmd_${times}.out 2>&1
    tmux kill-session -t ${rcv_tmux}

    ssh root@22.22.22.173 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@100.0.0.100 ssh root@192.168.0.2 tmux send-keys -t ${ipu_tmux} "quit" Enter
    ssh root@22.22.22.173 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@100.0.0.100 ssh root@192.168.0.2 tmux capture-pane -pS - -t ${ipu_tmux} >> ${run_path}/lab_results/ipu_log/ipu_${times}.out 2>&1
    ssh root@22.22.22.173 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@100.0.0.100 ssh root@192.168.0.2 tmux kill-session -t ${ipu_tmux}
    ((times++))
done



