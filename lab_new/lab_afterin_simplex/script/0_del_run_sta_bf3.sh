# parameter
file=pkt_send_mul_auto_sta6
remotefile=pkt_rcv_mul_auto_sta3
lab=lab_afterin_simplex

arm_ip="10.15.198.164"

run_path="/home/qyn/software/FastNIC/lab_new/$lab"
# ovs_path="/home/ubuntu/software/FastNIC/lab_results/ovs_log"

cd $run_path
rm ./lab_results/log/remote.out
rm ./lab_results/log/bf3.out
rm ./lab_results/log/bf3_arm.out


rm -rf ./lab_results/$file/*
rm -rf ./lab_results/$remotefile/*
rm -rf ./lab_results/arm_log/*

# rm -rf ./lab_results/ovslog/*
# ssh ubuntu@$arm_ip "cd $ovs_path && rm -f ./*.csv"

echo "del former file successfully"
