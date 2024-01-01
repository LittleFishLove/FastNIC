// #define SRC_IP_NUM 1000
// #define DST_IP_NUM 1429
// #define FLOW_NUM 100

#define FLOW_NUM 3
#define FLOW_SIZE 1000
#define PKTS_NUM (FLOW_SIZE*FLOW_NUM)

#define PKT_LEN 64
#define MAX_RECORD_COUNT 60
#define PROGRAM "pkt_send_mul_auto_sta6"

#define THROUGHPUT_FILE TPUT_PFX "/lab_results/" PROGRAM "/throughput.csv"
#define THROUGHPUT_TIME_FILE TPUT_PFX "/lab_results/" PROGRAM "/throughput_time.csv"