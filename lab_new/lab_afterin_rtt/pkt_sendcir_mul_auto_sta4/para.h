#define FLOW_NUM 100
#define PKT_LEN 64
#define MAX_RECORD_COUNT 10
#define PROGRAM "pkt_sendcir_mul_auto_sta4"

#define THROUGHPUT_FILE TPUT_PFX "/lab_results/" PROGRAM "/throughput.csv"
#define THROUGHPUT_TIME_FILE TPUT_PFX "/lab_results/" PROGRAM "/throughput_time.csv"

#define PKTS_NUM ((2e7) * MAX_RECORD_COUNT)

#define RTT_FILE TPUT_PFX "/lab_results/" PROGRAM "/rtt%d.csv"