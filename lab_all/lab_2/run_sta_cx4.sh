file=pkt_send_mul_auto_sta5_1
remotefile=pkt_rcv_mul_auto_sta3
lab=lab_2

line="bf2"
# line="cx5"

user="qyn"
if [[ ${user} == "cz" ]]
then
    run_path="/home/cz/3_20/FastNIC"
    password="123456"
elif [[ ${user} == "qyn" ]]
then
    run_path="/home/qyn/software/FastNIC/lab_all/${lab}"
    password="nesc77qq"
fi


core_id="0"
pkt_len=-1
flow_size=-1
srcip_num=-1
dstip_num=-1
test_time_rcv=50
test_time_send=30

flow_num_list=(10 100 1000 10000 20000 30000 40000 50000 60000 70000 80000 90000 100000)
# flow_num_list=(10 100000 1000000)
cir_time=${#flow_num_list[@]}

for ((i=0; i<$cir_time; i++))
do
    flow_num=${flow_num_list[$i]}
    echo "expect remote_bf2_config.expect"
    expect remote_bf2_config.expect

    send_run_para="flow_num $flow_num pkt_len $pkt_len flow_size $flow_size test_time $test_time_send srcip_num $srcip_num dstip_num $dstip_num"
    rcv_run_para="flow_num $flow_num pkt_len 64 flow_size $flow_size test_time $test_time_rcv srcip_num $srcip_num dstip_num $dstip_num"

    echo "expect remote_run_sta_cx4.expect $run_path $user $password $remotefile $line \"$rcv_run_para\" >> ./lab_results/log/remote.out 2>&1 &"
    expect remote_run_sta_cx4.expect $run_path $user $password $remotefile $line "$rcv_run_para" >> ./lab_results/log/remote.out 2>&1 &
    sleep 8s

    echo ./start_sta.sh $file $line 161 $core_id $run_path \"$send_run_para\"
    ./start_sta.sh $file $line 161 $core_id $run_path "$send_run_para" #149,bf2tocx4
    sleep 30s

    mkdir ./lab_results/${file}/send_$i
    mv ./lab_results/${file}/*.csv ./lab_results/${file}/send_$i/
    echo -e "off_thre\r\n${off_thre}" > ./lab_results/${file}/send_$i/para.csv

    ssh qyn@10.15.198.160 "cd $run_path && mkdir ./lab_results/${remotefile}/rcv_$i"
    ssh qyn@10.15.198.160 "cd $run_path/lab_results/${remotefile}/ && mv *csv rcv_$i/"
       
    ovsfile_path="/home/ubuntu/software/FastNIC/lab_results/ovs_log"
    mkdir ./lab_results/ovslog/log_$i
    scp -o ProxyJump=qyn@10.15.198.160 ubuntu@192.168.100.2:$ovsfile_path/*.csv $run_path/lab_results/ovslog/log_$i
    ssh -A -t qyn@10.15.198.160 ssh ubuntu@192.168.100.2 "cd $ovsfile_path && rm -f ./*.csv"
done

