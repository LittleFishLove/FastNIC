# test_time_rcv=120
# test_time_send=100
test_time_rcv=50
test_time_send=30
lab=lab_openloop
file=pkt_send_mul_auto_sta3
remotefile=pkt_rcv_mul_auto_sta3
line="bf2"
# line="cx5"

user="qyn"
if [[ ${user} == "cz" ]]
then
    run_path="/home/cz/3_20/FastNIC"
    password="123456"
elif [[ ${user} == "qyn" ]]
then
    run_path="/home/qyn/software/FastNIC/$lab"
    password="nesc77qq"
fi

cd $run_path
i=0
# flow_size=1000000000
flow_num=100000
# for core_id in {"0","0,2","0,2,4,6","0,2,4,6,8,10,12,14","0,2,4,6,8,10,12,14,16,18,20,22","0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30","0-31"}
for core_id in {"0","0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30"}
do
    # for flow_num in {100,1000,10000,30000,50000,70000,90000,100000}
    # for flow_num in {1000,100000}
    for flow_size in {10,1000000000}
    do
        expect remote_run_sta_cx4.expect $test_time_rcv $run_path $user $password $remotefile $line >> ./lab_results/log/remote.out 2>&1 &
        sleep 8s
        echo ./start_sta.sh $file $line 161 $core_id $flow_num 64 $flow_size $test_time_send $run_path
        ./start_sta.sh $file $line 161 $core_id $flow_num 64 $flow_size $test_time_send $run_path #149,bf2tocx4
        # ./start_sta.sh pkt_send_mul_auto_sta3 bf2 150 0 1000 64 100000 10 /home/qyn/software/FastNIC/lab_openloop
        sleep 30s

        ((i++))

        mkdir ./lab_results/${file}/send_$i
        mv ./lab_results/${file}/*.csv ./lab_results/${file}/send_$i/
        
        ssh qyn@10.15.198.160 "cd $run_path && mkdir ./lab_results/${remotefile}/rcv_$i"
        ssh qyn@10.15.198.160 "cd $run_path/lab_results/${remotefile}/ && mv *csv rcv_$i/"
       
        ovsfile_path="/home/ubuntu/software/FastNIC/lab_results/ovs_log"
        mkdir ./lab_results/ovslog/log_$i
        scp -o ProxyJump=qyn@10.15.198.160 ubuntu@192.168.100.2:$ovsfile_path/*.csv $run_path/lab_results/ovslog/log_$i
        ssh -A -t qyn@10.15.198.160 ssh ubuntu@192.168.100.2 "cd $ovsfile_path && rm -f ./*.csv"
    done
done

# ./start.sh pkt_rcv_multicore enp59s0f0 "192.168.200.2" 0,1 #149,bf2tocx4

# ./start.sh pkt_send_multicore enp216s0 "192.168.201.2" 0,1,2 #149,cx5
# ./start.sh pkt_send_multicore ens1np0 "192.168.200.1" 0,1 #150,cx4tobf2
# ./start.sh pkt_send_multicore ens3np0 "192.168.201.1" 0,1 #150,cx5
