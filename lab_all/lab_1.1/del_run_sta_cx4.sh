# parameter
file=pkt_sendcir_mul_auto_sta2
remotefile=pkt_rcvcir_mul_auto_sta
lab="lab_1.1"
run_path="/home/qyn/software/FastNIC/lab_all/${lab}.1"

ovs_path="/home/ubuntu/software/FastNIC/lab_results/ovs_log"

cd $run_path
rm ./lab_results/log/remote.out
rm ./lab_results/log/cx4.out
# rm ./lab_results/log/remote_bfconfig.out
rm -rf ./lab_results/$file/*
ssh qyn@10.15.198.149 "cd $run_path && rm -rf ./lab_results/$remotefile/*"
rm -rf ./lab_results/ovslog/*
ssh ubuntu@10.15.198.148 "cd $ovs_path && rm -f ./*.csv"

echo "del former file successfully"
