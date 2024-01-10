// #define SRC_IP_NUM 1000
// #define DST_IP_NUM 1429
// #define FLOW_NUM 20

#define FLOW_NUM 10
#define FLOW_SIZE 1000
#define PKT_LEN 64
#define MAX_RECORD_COUNT 10
#define PROGRAM "pkt_sendcir_mul_auto_sta2"

// #define PKTS_NUM (FLOW_SIZE*FLOW_NUM)
#define PKTS_NUM ((2e7) * MAX_RECORD_COUNT)

#define THROUGHPUT_FILE TPUT_PFX "/lab_results/" PROGRAM "/throughput.csv"
#define THROUGHPUT_TIME_FILE TPUT_PFX "/lab_results/" PROGRAM "/throughput_time.csv"

#define RTT_FILE TPUT_PFX "/lab_results/" PROGRAM "/rtt%d.csv"