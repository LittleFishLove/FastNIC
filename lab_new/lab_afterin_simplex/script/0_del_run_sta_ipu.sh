# parameter
file=pkt_send_mul_auto_sta6
lab=lab_afterin_simplex

run_path="/root/qyn/FastNIC/lab_new/${lab}"
ipu_run_path="/root/LAB_code/FastNIC/lab_new/${lab}"

# ovs_path="/home/ubuntu/software/FastNIC/lab_results/ovs_log"

cd $
ssh root@22.22.22.173 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@100.0.0.100 ssh root@192.168.0.2 ${ipu_run_path}/script/ipu_run.sh
rm .script/ipu_run.sh
rm ./lab_results/log/ipu.out

rm -rf ./lab_results/$file/*
rm -rf ./lab_results/rcv/*
rm -rf ./lab_results/ipu_log/*

# rm -rf ./lab_results/ovslog/*
# ssh ubuntu@$arm_ip "cd $ovs_path && rm -f ./*.csv"

echo "del former file successfully"