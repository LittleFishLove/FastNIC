# 发包含不同数量flows，zipf分布不同的流，
# off2，测试不同的off_thre
file=pkt_send_mul_auto_sta4_2
remotefile=pkt_rcv_mul_auto_sta3
lab=lab_simplex

line="bf2"
# line="cx5"

user="qyn"
if [[ ${user} == "cz" ]]
then
    run_path="/home/cz/3_20/FastNIC"
    password="123456"
elif [[ ${user} == "qyn" ]]
then
    run_path="/home/qyn/software/FastNIC/lab_new/${lab}"
    password="nesc77qq"
fi

if [[ ! -d "${run_path}/lab_results/ovslog" ]]
then
    mkdir -p ${run_path}/lab_results/ovslog
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

test_time_rcv=30
test_time_send=10

# off_thre_list=(1 2 3 4 5 7 10 20 30)
# off_thre_list=(1 2 3)
cir_time_ot=${#off_thre_list[@]}
flow_num_list=(100000 10000 100)
cir_time_fn=${#flow_num_list[@]}
zipf_para_list=(1.1 2.0)
# zipf_para_list=(1.1 1.2 1.3 1.5 1.7 2.0)
cir_time_zp=${#zipf_para_list[@]}

times=0
# for ((i=0; i<$cir_time_ot; i++))
# do
    # off_thre=${off_thre_list[$i]}
    # echo "expect remote_bf2_config.expect $off_thre"
    # expect remote_bf2_config.expect $off_thre
    for ((j=0; j<$cir_time_fn; j++))
    do
        flow_num=${flow_num_list[$j]}

        for ((k=0; k<$cir_time_zp; k++))
        do
            zipf_para=${zipf_para_list[$k]}

            send_run_para="flow_num $flow_num pkt_len $pkt_len flow_size $flow_size test_time $test_time_send srcip_num $srcip_num dstip_num $dstip_num zipf_para $zipf_para"
            rcv_run_para="flow_num $flow_num pkt_len 64 flow_size $flow_size test_time $test_time_rcv srcip_num $srcip_num dstip_num $dstip_num zipf_para -1"

            echo "expect remote_run_sta_cx4.expect $run_path $user $password $remotefile $line \"$rcv_run_para\" >> ../lab_results/log/remote.out 2>&1 &"
            expect remote_run_sta_cx4.expect $run_path $user $password $remotefile $line "$rcv_run_para" >> ../lab_results/log/remote.out 2>&1 &
            sleep 8s

            echo ./start_sta.sh $file $line 150 $core_id $run_path \"$send_run_para\"
            ./start_sta.sh $file $line 150 $core_id $run_path "$send_run_para" #149,bf2tocx4
            sleep 30s

            mkdir ${run_path}/lab_results/${file}/send_$times
            mv ${run_path}/lab_results/${file}/*.csv ${run_path}/lab_results/${file}/send_$times/
            echo -e "off_thre,zipf_para\r\n${off_thre},${zipf_para}" > ${run_path}/lab_results/${file}/send_$times/para.csv

            ssh qyn@10.15.198.149 "cd $run_path && mkdir -p ./lab_results/${remotefile}/rcv_$times"
            ssh qyn@10.15.198.149 "cd $run_path/lab_results/${remotefile}/ && mv *csv rcv_$times/"
            
            ovsfile_path="/home/ubuntu/software/FastNIC/lab_results/ovs_log"
            mkdir ${run_path}/lab_results/ovslog/log_$times
            scp ubuntu@10.15.198.148:$ovsfile_path/*.csv $run_path/lab_results/ovslog/log_$times
            ssh ubuntu@10.15.198.148 "cd $ovsfile_path && rm -f ./*.csv"
            ((times++))
        done
    done
# done
