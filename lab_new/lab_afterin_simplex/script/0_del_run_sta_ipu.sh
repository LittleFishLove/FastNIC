# parameter
file=pkt_send_mul_auto_sta6
lab=lab_afterin_simplex

run_path="/root/qyn/FastNIC/lab_new/${lab}"
# ovs_path="/home/ubuntu/software/FastNIC/lab_results/ovs_log"

cd $run_path
rm ./lab_results/log/ipu.out

rm -rf ./lab_results/$file/*
rm -rf ./lab_results/rcv/*
rm -rf ./lab_results/ipu_log/*

# rm -rf ./lab_results/ovslog/*
# ssh ubuntu@$arm_ip "cd $ovs_path && rm -f ./*.csv"

echo "del former file successfully"