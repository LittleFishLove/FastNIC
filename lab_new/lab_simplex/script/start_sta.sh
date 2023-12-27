file_name=$1 
line=$2
host_name=$3
core_id=$4
run_path=$5

arr=($6)

#read parameter
for ((i=0; i<${#arr[@]}; i+=2)); do
    key=${arr[$i]}
    value=${arr[$i+1]}
    eval "$key='$value'"
    echo "$key=$value"
done

# determine nic, ip, mac
if [[ $line == "bf2" && $host_name == 149 ]] #bf2-cx4
then 
    src_nic_name="enp216s0f0"
    dst_ip="192.168.200.2"
    dst_mac="b8:83:03:82:a2:10"
elif [[ $line == "bf2" && $host_name == 150 ]] #cx4-bf2
then 
    src_nic_name="ens1np0"
    dst_ip="192.168.200.1"
    dst_mac="0c:42:a1:d8:10:84"
elif [[ $line == "cx5" && $host_name == 149 ]] #cx5(withbf2)-cx5(withcx4)
then 
    src_nic_name="enp175s0"
    dst_ip="192.168.201.2"
    dst_mac="08:c0:eb:de:43:2e"
elif [[ $line == "cx5" && $host_name == 150 ]] #cx5(withbf4)-cx5(withcx5)
then 
    src_nic_name="ens3np0"
    dst_ip="192.168.201.1"
    dst_mac="08:c0:eb:de:41:f2"
elif [[ $line == "nusbf2" && $host_name == "node11" ]] 
then
    src_nic_name="ens1f0np0"
    dst_ip="192.168.200.2"
    dst_mac="10:70:fd:c8:94:74"
elif [[ $line == "nusbf2" && $host_name == "node12" ]] 
then
    src_nic_name="enp177s0f0"
    dst_ip="192.168.200.1"
    dst_mac="b8:ce:f6:a8:82:a6"
elif [[ $line == "bf3" && $host_name == "node1" ]] 
then
    src_nic_name="ens22f0np0"
    dst_ip="192.168.200.2"
    dst_mac="08:c0:eb:de:43:8e"
elif [[ $line == "bf3" && $host_name == "node2" ]] 
then
    src_nic_name="ens22np0"
    dst_ip="192.168.200.1"
    dst_mac="a0:88:c2:31:fb:6e"
elif [[ $line == "186-171" && $host_name == "186_ali" ]] 
then
    src_nic_name="ens5f0"
    dst_ip=""
    dst_mac="00:11:00:00:03:14"
elif [[ $line == "bf3" && $host_name == "node2" ]] 
then
    src_nic_name="ens29f0v1"
    dst_ip=""
    dst_mac="b8:59:9f:f0:80:a4"
fi


src_mac=`ifconfig ${src_nic_name}|grep ether|awk '{print $2}'`
src_pci=`ethtool -i ${src_nic_name}|grep bus-info|awk '{print $2}'`
# dst_mac=`arp ${dst_ip}|grep ether|awk '{print $3}'`

echo run ${file_name} app, from ${src_nic_name} to ${dst_ip}
echo src_mac:${src_mac},src_pci:${src_pci}
echo dst_mac:${dst_mac}
echo -e '\n'

if [[ ${host_name} == "149" ]]
then
    export PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig/
elif [[ ${host_name} == "150" || ${host_name} == "node11" || ${host_name} == "node12" ]]
then
    export PKG_CONFIG_PATH=/usr/local/lib/x86_64-linux-gnu/pkgconfig/
fi

if [[ ${host_name} == "186_ali" ]]
then
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib64
    source /opt/rh/devtoolset-11/enable
fi

cd $run_path/$file_name/

if [[ ! -d "../lab_results/${file_name}" ]]
then
    mkdir -p ../lab_results/${file_name}
fi

echo "sudo ./build/$file_name -l ${core_id} -a ${src_pci} -- --srcmac ${src_mac} --dstmac ${dst_mac}"
if [[ ${file_name} == "pkt_send_mul_auto_sta" || \
      ${file_name} == "pkt_send_mul_auto_sta2" ]]
then
    sed -i "s/#define FLOW_NUM.*$/#define FLOW_NUM ${flow_num}/" para.h
    sed -i "s/#define PKT_LEN.*$/#define PKT_LEN ${pkt_len}/" para.h
    sed -i "s/#define MAX_RECORD_COUNT.*$/#define MAX_RECORD_COUNT ${test_time}/" para.h
    make clean
    make
    sudo ./build/$file_name -l ${core_id} -a ${src_pci} -- --srcmac ${src_mac} --dstmac ${dst_mac} 
elif [[ ${file_name} == "pkt_send_mul_auto_sta3" || \
        ${file_name} == "pkt_loopsend_mul_sta" ]]
then
    sed -i "s/#define FLOW_NUM.*$/#define FLOW_NUM ${flow_num}/" para.h
    sed -i "s/#define PKT_LEN.*$/#define PKT_LEN ${pkt_len}/" para.h
    sed -i "s/#define MAX_RECORD_COUNT.*$/#define MAX_RECORD_COUNT ${test_time}/" para.h
    sed -i "s/#define FLOW_SIZE.*$/#define FLOW_SIZE ${flow_size}/" para.h
    make clean
    make
    sudo ./build/$file_name -l ${core_id} -a ${src_pci} -- --srcmac ${src_mac} --dstmac ${dst_mac} 
elif [[ ${file_name} == "pkt_send_mul_auto_sta4" || \
        ${file_name} == "pkt_send_mul_auto_sta5_2" || \
        ${file_name} == "pkt_send_mul_auto_sta5_3" ]]
then
    sed -i "s/#define FLOW_NUM.*$/#define FLOW_NUM ${flow_num}/" para.h
    sed -i "s/#define MAX_RECORD_COUNT.*$/#define MAX_RECORD_COUNT ${test_time}/" para.h
    make clean
    make
    sudo ./build/$file_name -l ${core_id} -a ${src_pci} -- --srcmac ${src_mac} --dstmac ${dst_mac} 
elif [[ ${file_name} == "pkt_send_mul_auto_sta5_1" ]]
then
    sed -i "s/#define FLOW_NUM.*$/#define FLOW_NUM ${flow_num}/" para.h
    sed -i "s/#define FLOW_SIZE.*$/#define FLOW_SIZE ${flow_size}/" para.h
    sed -i "s/#define MAX_RECORD_COUNT.*$/#define MAX_RECORD_COUNT ${test_time}/" para.h
    make clean
    make
    sudo ./build/$file_name -l ${core_id} -a ${src_pci} -- --srcmac ${src_mac} --dstmac ${dst_mac} 


elif [[ ${file_name} == "pkt_send_mul_auto_sta4" ]]
then
    sed -i "s/#define FLOW_SIZE.*$/#define FLOW_SIZE ${flow_size}/" para.h
    sed -i "s/#define SRC_IP_NUM.*$/#define SRC_IP_NUM ${srcip_num}/" para.h
    sed -i "s/#define DST_IP_NUM.*$/#define DST_IP_NUM ${dstip_num}/" para.h
    sed -i "s/#define MAX_RECORD_COUNT.*$/#define MAX_RECORD_COUNT ${test_time}/" para.h
    make clean
    make
    sudo ./build/$file_name -l ${core_id} -a ${src_pci} -- --srcmac ${src_mac} --dstmac ${dst_mac} 
elif [[ ${file_name} == "pkt_rcv_mul_auto_sta" || \
        ${file_name} == "pkt_rcv_mul_auto_sta3" || \
        ${file_name} == "pkt_looprcv_mul_sta" ]]
then
    sed -i "s/#define MAX_RECORD_COUNT.*$/#define MAX_RECORD_COUNT ${test_time}/" para.h
    make clean
    make
    sudo ./build/$file_name -l ${core_id} -a ${src_pci}
elif [[ ${file_name} == "pkt_send_mul_auto_sta4_2" || \
        ${file_name} == "pkt_send_mul_auto_sta5_4" ]]
then
    sed -i "s/#define FLOW_NUM.*$/#define FLOW_NUM ${flow_num}/" para.h
    sed -i "s/#define MAX_RECORD_COUNT.*$/#define MAX_RECORD_COUNT ${test_time}/" para.h
    sed -i "s/#define ZIPF_PARA.*$/#define ZIPF_PARA ${zipf_para}/" para.h
    make clean
    make
    sudo ./build/$file_name -l ${core_id} -a ${src_pci} -- --srcmac ${src_mac} --dstmac ${dst_mac} 
elif [[ ${file_name} == "pkt_send_mul_auto_sta6" ]]
then
    make clean
    make
    sudo ./build/$file_name -l ${core_id} -a ${src_pci} -- --srcmac ${src_mac} --dstmac ${dst_mac} 
fi
