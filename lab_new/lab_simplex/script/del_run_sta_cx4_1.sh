# parameter
file=pkt_send_mul_auto_sta5_1
remotefile=pkt_rcv_mul_auto_sta3
lab=lab_simplex

run_path="/home/qyn/software/FastNIC/lab_new/$lab"
ovs_path="/home/ubuntu/software/FastNIC/lab_results/ovs_log"

cd $run_path 
rm ./lab_results/log/remote.out
rm ./lab_results/log/cx4.out
rm -rf ./lab_results/$file/*
ssh qyn@10.15.198.149 "cd $run_path && rm -rf ./lab_results/$remotefile/*"
rm -rf ./lab_results/ovslog/*
ssh ubuntu@10.15.198.148 "cd $ovs_path && rm -f ./*.csv"

echo "del former file successfully"
