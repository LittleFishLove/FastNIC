#include <stdint.h>
#include <stdarg.h>
#include <ctype.h>
#include <errno.h>
#include <getopt.h>
#include <signal.h>
#include <stdbool.h>
#include <inttypes.h>
#include <rte_common.h>
#include <rte_log.h>
#include <rte_eal.h>
#include <rte_ethdev.h>
#include <rte_cycles.h>
#include <rte_lcore.h>
#include <rte_mbuf.h>
#include <rte_prefetch.h>
#include <rte_ether.h>
#include <rte_ip.h>
#include <unistd.h> // For sleep()
#include <sys/time.h> //For gettimeofday()

#include "para.h"

#define APP_ETHER_TYPE  0x2222
#define APP_MAGIC       0x3333

#define MAX_LCORES 72
#define RX_QUEUE_PER_LCORE   1
#define TX_QUEUE_PER_LCORE   1

#define RX_RING_SIZE 1024
#define TX_RING_SIZE 1024
#define NUM_MBUFS 4095
#define MBUF_SIZE   (2048+sizeof(struct rte_mbuf)+RTE_PKTMBUF_HEADROOM)
#define MBUF_CACHE_SIZE 32
#define BURST_SIZE 64
#define TX_BURST_SIZE 16
#define RX_BURST_SIZE 64

#define IP_PROTO_UDP 17
#define IP_PROTO_TCP 6
// #define PCAP_ENABLE

#define HOST_TO_NETWORK_16(value) ((uint16_t)(((value) >> 8) | ((value) << 8)))

#define GET_RTE_HDR(t, h, m, o) \
    struct t *h = rte_pktmbuf_mtod_offset(m, struct t *, o)
#define APP_LOG(...) RTE_LOG(INFO, USER1, __VA_ARGS__)
#define PRN_COLOR(str) ("\033[0;33m" str "\033[0m")	// Yellow accent

#define SRC_IP_PREFIX ((10<<24)) /* src ip prefix = 10.0.0.0.0 */

struct rte_eth_conf port_conf = {
	.rxmode = {
		.mq_mode = RTE_ETH_MQ_RX_RSS,
	},
	.rx_adv_conf = {
		.rss_conf = {
			.rss_key = NULL,
			.rss_hf = RTE_ETH_RSS_IP | RTE_ETH_RSS_TCP | RTE_ETH_RSS_UDP,
		},
	},
};

struct lcore_configuration {
    uint32_t vid; // virtual core id
    uint32_t port; // one port
    uint32_t n_tx_queue;  // number of TX queues
    uint32_t tx_queue_list[TX_QUEUE_PER_LCORE]; // list of TX queues
    uint32_t n_rx_queue;  // number of RX queues
    uint32_t rx_queue_list[RX_QUEUE_PER_LCORE]; // list of RX queues
} __rte_cache_aligned;

struct payload {
    uint64_t timestamp;
    uint32_t pkt_seq;
};


struct meta_date{
    uint32_t pkt_seq;
};


struct flow_log {
    double tx_pps_t;
    double tx_bps_t;
    double rx_pps_t;
    double rx_bps_t;
};

struct header_info {
    struct rte_ether_addr eth_dst;
    struct rte_ether_addr eth_src;
    uint32_t ipv4_dst;
    uint32_t ipv4_src;
    uint16_t tcp_port_dst;
    uint16_t tcp_port_src;
};


static unsigned enabled_port = 0;
static struct rte_ether_addr mac_addr;
static uint64_t min_txintv = 15/*us*/;	// min cycles between 2 returned packets
static volatile bool force_quit = false;
static volatile uint16_t nb_pending = 0;

struct lcore_configuration lcore_conf[MAX_LCORES];
struct rte_mempool *pktmbuf_pool[MAX_LCORES];

uint64_t tx_pkt_num[MAX_LCORES];
uint64_t rx_pkt_num[MAX_LCORES];
uint64_t tx_pps[MAX_LCORES];
uint64_t rx_pps[MAX_LCORES];
double tx_bps[MAX_LCORES];
double rx_bps[MAX_LCORES];
struct flow_log *flowlog_timeline[MAX_LCORES];

static inline void
fill_ethernet_header(struct rte_ether_hdr *eth_hdr, struct header_info *hdr) {
	struct rte_ether_addr s_addr = hdr->eth_src; 
	struct rte_ether_addr d_addr = hdr->eth_dst;
	eth_hdr->src_addr =s_addr;
	eth_hdr->dst_addr =d_addr;
	eth_hdr->ether_type = rte_cpu_to_be_16(0x0800);
}

static inline void
fill_ipv4_header(struct rte_ipv4_hdr *ipv4_hdr, struct header_info *hdr) {
	ipv4_hdr->version_ihl = (4 << 4) + 5; // 0x45
	ipv4_hdr->type_of_service = 0; // 0x00
	ipv4_hdr->total_length = rte_cpu_to_be_16(PKT_LEN); // tcp 20
	ipv4_hdr->packet_id = rte_cpu_to_be_16(1); // set random
	ipv4_hdr->fragment_offset = rte_cpu_to_be_16(0);
	ipv4_hdr->time_to_live = 64;
	ipv4_hdr->next_proto_id = IP_PROTO_TCP; 
	ipv4_hdr->hdr_checksum = rte_cpu_to_be_16(0x0);

    ipv4_hdr->src_addr = rte_cpu_to_be_32(hdr->ipv4_src); 
	ipv4_hdr->dst_addr = rte_cpu_to_be_32(hdr->ipv4_dst);

	ipv4_hdr->hdr_checksum = rte_cpu_to_be_16(HOST_TO_NETWORK_16(rte_ipv4_cksum(ipv4_hdr)));
}

// static inline void
// fill_udp_header(struct rte_udp_hdr *udp_hdr, struct rte_ipv4_hdr *ipv4_hdr, struct header_info *hdr) {
//     udp_hdr->src_port = rte_cpu_to_be_16(flow_id->src_port);
// 	udp_hdr->dst_port = rte_cpu_to_be_16(flow_id->dst_port);
// 	udp_hdr->dgram_len = rte_cpu_to_be_16(PKT_LEN - sizeof(struct rte_ipv4_hdr));
//     udp_hdr->dgram_cksum = rte_cpu_to_be_16(0x0);
	
// 	udp_hdr->dgram_cksum = rte_cpu_to_be_16(rte_ipv4_udptcp_cksum(ipv4_hdr, udp_hdr));
// }

static inline void
fill_tcp_header(struct rte_tcp_hdr *tcp_hdr, struct rte_ipv4_hdr *ipv4_hdr, struct header_info *hdr) {
	tcp_hdr->src_port = rte_cpu_to_be_16(hdr->tcp_port_src);
	tcp_hdr->dst_port = rte_cpu_to_be_16(hdr->tcp_port_dst);
	tcp_hdr->sent_seq = rte_cpu_to_be_32(0);
	tcp_hdr->recv_ack = rte_cpu_to_be_32(0);
	tcp_hdr->data_off = 0x50;
	tcp_hdr->tcp_flags = 2;
	tcp_hdr->rx_win = HOST_TO_NETWORK_16(rte_cpu_to_be_16(32));
	tcp_hdr->cksum = rte_cpu_to_be_16(0x0);
	tcp_hdr->tcp_urp = rte_cpu_to_be_16(0);

	tcp_hdr->cksum = rte_cpu_to_be_16(rte_ipv4_udptcp_cksum(ipv4_hdr, tcp_hdr));
}

static inline void
fill_payload(struct payload *payload_data, struct meta_date *pkt_meta) {
    // payload_data->pkt_seq = flow->pkt_seq;
    payload_data->timestamp = rte_rdtsc(); 
    payload_data->pkt_seq = pkt_meta->pkt_seq;
    // flow->pkt_seq++;
}

static struct rte_mbuf *make_testpkt(uint32_t queue_id, struct header_info *hdr, struct meta_date *pkt_meta)
{
    
    struct rte_mbuf *mp = rte_pktmbuf_alloc(pktmbuf_pool[queue_id]);

    uint16_t pkt_len = PKT_LEN+sizeof(struct rte_ether_hdr);
    char *buf = rte_pktmbuf_append(mp, pkt_len);
    if (unlikely(buf == NULL)) {
        APP_LOG("Error: failed to allocate packet buffer.\n");
        rte_pktmbuf_free(mp);
        return NULL;
    }

    mp->data_len = pkt_len;
    mp->pkt_len = pkt_len;
    uint16_t curr_ofs = 0;

    struct rte_ether_hdr *ether_h = rte_pktmbuf_mtod_offset(mp, struct rte_ether_hdr *, curr_ofs);
	fill_ethernet_header(ether_h, hdr);
    curr_ofs += sizeof(struct rte_ether_hdr);

    struct rte_ipv4_hdr *ipv4_h = rte_pktmbuf_mtod_offset(mp, struct rte_ipv4_hdr *, curr_ofs);
	fill_ipv4_header(ipv4_h, hdr);
    curr_ofs += sizeof(struct rte_ipv4_hdr);

    // struct rte_udp_hdr *udp_h = rte_pktmbuf_mtod_offset(mp, struct rte_udp_hdr *, curr_ofs);
	// fill_udp_header(udp_h, ipv4_h,hdr);
    // curr_ofs += sizeof(struct rte_udp_hdr);

    struct rte_tcp_hdr *tcp_h = rte_pktmbuf_mtod_offset(mp, struct rte_tcp_hdr *, curr_ofs);
	fill_tcp_header(tcp_h, ipv4_h, hdr);
    curr_ofs += sizeof(struct rte_tcp_hdr);

    struct payload * payload_data= rte_pktmbuf_mtod_offset(mp, struct payload *, curr_ofs);
    fill_payload(payload_data, pkt_meta);

    return mp;
}


/*
 * The lcore main. This is the main thread that does the work, reading from
 * an input port and writing to an output port.
 */

static void lcore_main(uint32_t lcore_id)
{
    // Check that the port is on the same NUMA node.
    if (rte_eth_dev_socket_id(enabled_port) > 0 &&
            rte_eth_dev_socket_id(enabled_port) != (int)rte_socket_id())
        printf("WARNING, port %u is on remote NUMA node.\n", enabled_port);

    /* Run until the application is quit or killed. */
    struct lcore_configuration *lconf = &lcore_conf[lcore_id];
    uint32_t queue_id;
    struct rte_mbuf *bufs_rx[RX_BURST_SIZE], *bufs_tx[TX_BURST_SIZE];
    
    int pkt_batch_count = 0;
    
    uint64_t pkt_count = 0;
    uint64_t loop_count = 0;
    uint64_t record_count = 0;
    /* pkts_sta */
    uint64_t total_tx = 0, total_rx = 0;
    uint64_t txB[TX_BURST_SIZE], rxB[RX_BURST_SIZE];
    uint64_t total_txB = 0, total_rxB = 0;
    uint64_t last_total_tx = 0, last_total_rx = 0;
    uint64_t last_total_txB = 0, last_total_rxB = 0;
    // uint64_t total_txb = 0, total_rxb = 0; //we send same length packets now, can be ignored
    /* time_sta */
    uint64_t start = rte_rdtsc();
    uint64_t time_last_print = start;
    uint64_t time_now;

    double rtt;
    double *rtt_list = malloc(sizeof(double) * PKTS_NUM);
    memset(rtt_list, 0 , sizeof(double) * PKTS_NUM);
    uint32_t *pkt_seq_list = malloc(sizeof(uint32_t) * PKTS_NUM);
    memset(pkt_seq_list, 0 , sizeof(uint32_t) * PKTS_NUM);
    uint64_t rtt_len = 0;

    if (unlikely(flowlog_timeline[lcore_id] != NULL)){
        rte_exit(EXIT_FAILURE, "There are error when allocate memory to flowlog.\n");
    }else{
        flowlog_timeline[lcore_id] = (struct flow_log *) malloc(sizeof(struct flow_log) * MAX_RECORD_COUNT);
        memset(flowlog_timeline[lcore_id], 0, sizeof(struct flow_log) * MAX_RECORD_COUNT);
    }

    int i, j;
    #ifdef PCAP_ENABLE
    for (i = 0; i < lconf->n_rx_queue; i++){
        queue_id = lconf->rx_queue_list[i];
        pkt_buffer[queue_id].mbufs = (struct rte_mbuf **) malloc(sizeof(struct rte_mbuf *) * PKTS_NUM);
        //initialize pkt_buffer
        int num_allocated = rte_pktmbuf_alloc_bulk(pktmbuf_pool[queue_id], 
                               pkt_buffer[queue_id].mbufs, PKTS_NUM);
        pkt_buffer[queue_id].count = 0;
        pkt_buffer[queue_id].lcore_id = lcore_id;
        pkt_buffer[queue_id].queue_id = queue_id;
        if(pcap_loop(handle, -1, packet_handler, (u_char *)&pkt_buffer[queue_id]) != 0){
            rte_exit(EXIT_FAILURE, "Error in pcap_loop: %s\n", pcap_geterr(handle));
        }
    }
    #endif

    printf("Core %u forwarding packets. [Ctrl+C to quit]\n", rte_lcore_id());
    fflush(stdout);

    while (!force_quit && record_count < MAX_RECORD_COUNT && rtt_len <= (PKTS_NUM - BURST_SIZE)) {
    // while (!force_quit && record_count < MAX_RECORD_COUNT && pkt_count < PKTS_NUM) {
        for (i = 0; i < lconf->n_rx_queue; i++){
            #ifdef PCAP_ENABLE
            rte_pktmbuf_alloc_bulk(pktmbuf_pool[queue_id], 
                                   bufs_tx, 
                                   BURST_SIZE);
            #endif

            struct header_info hdr_info;
            uint32_t ip_dst, ip_src;
            struct meta_date pkt_meta;
            static const struct rte_ether_addr eth_dst = {{ 0x00, 0x08, 0x00, 0x00, 0x03, 0x14 }};
            static const struct rte_ether_addr eth_src = {{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x02 }};
            inet_pton(AF_INET, "192.168.0.1", &ip_dst);
            ip_dst = ntohl(ip_dst);
            inet_pton(AF_INET, "10.0.0.0", &ip_src);
            ip_src = ntohl(ip_src);

            hdr_info.eth_dst = eth_dst;
            hdr_info.eth_src = eth_src;
            hdr_info.ipv4_dst = ip_dst;
            hdr_info.ipv4_src = ip_src;
            hdr_info.tcp_port_dst = 1;
            hdr_info.tcp_port_src = 2;

            for (j = 0; j < TX_BURST_SIZE; j++){
                #ifndef PCAP_ENABLE
                ip_src = SRC_IP_PREFIX + (pkt_count % FLOW_NUM);
                pkt_meta.pkt_seq = pkt_count / FLOW_NUM;
                hdr_info.ipv4_src = ip_src;

                bufs_tx[j] = make_testpkt(lconf->rx_queue_list[i], &hdr_info, &pkt_meta);
                #endif
                /* packet copy from buffer to send*/
                // rte_memcpy(rte_pktmbuf_mtod(bufs_tx[j], void *), 
                //            rte_pktmbuf_mtod(pkt_buffer[queue_id].mbufs[pkt_count], void*), 
                //            pkt_buffer[queue_id].mbufs[pkt_count]->data_len); 
                // bufs_tx[j]->pkt_len = pkt_buffer[queue_id].mbufs[pkt_count]->pkt_len;
                // bufs_tx[j]->data_len = pkt_buffer[queue_id].mbufs[pkt_count]->data_len;
                txB[j] = bufs_tx[j]->data_len;
                pkt_count++;
            }
            // // packet hexadecimal print
            // int a;
            // printf("packet:\n");
            // uint8_t* pkt_p = (uint8_t*)rte_pktmbuf_mtod(bufs_tx[0], void *);
            // for(a = 0; a < ETH_HDR_LEN + IPV4_HDR_LEN + TCP_HDR_LEN + 10; a++){
            //     printf("%02x ", pkt_p[a]);
            //     if(a % 16 == 15){
            //         printf("%d-%d", a-15, a);
            //         printf("\n");
            //     }
            // }
            // printf("\n");
            // Send the packet batch
            uint16_t nb_tx = 0;
            // if(total_tx-total_rx < 1000){
            //     nb_tx = rte_eth_tx_burst(lconf->port, lconf->tx_queue_list[i], bufs_tx, BURST_SIZE);
            // }
            nb_tx = rte_eth_tx_burst(lconf->port, lconf->tx_queue_list[i], bufs_tx, TX_BURST_SIZE);

            total_tx += nb_tx;
            for (j = 0; j < nb_tx; j++){
                total_txB += txB[j];
            }
            if (nb_tx < TX_BURST_SIZE){
                rte_pktmbuf_free_bulk(bufs_tx + nb_tx, TX_BURST_SIZE - nb_tx);
            }

            const uint16_t nb_rx = rte_eth_rx_burst(lconf->port, lconf->rx_queue_list[i], bufs_rx, RX_BURST_SIZE);
            uint64_t rcv_time = rte_rdtsc();
            if(nb_rx != 0){
                total_rx += nb_rx;
                for(j = 0; j < nb_rx; j++){
                    total_rxB += (bufs_rx[j]->data_len);

                    uint16_t curr_ofs = sizeof(struct rte_ether_hdr) + sizeof(struct rte_ipv4_hdr) + sizeof(struct rte_tcp_hdr);
                    struct payload * payload_data= rte_pktmbuf_mtod_offset(bufs_rx[j], struct payload *, curr_ofs);
 
                    rtt_len ++;
                    rtt = (double)(rcv_time - payload_data->timestamp)/rte_get_timer_hz();
                    rtt_list[rtt_len] = rtt;
                    pkt_seq_list[rtt_len] = payload_data->pkt_seq;
                }
                rte_pktmbuf_free_bulk(bufs_rx, nb_rx);
            }
        }
        loop_count++;

        //save log
        time_now = rte_rdtsc();
        double time_inter_temp=(double)(time_now-time_last_print)/rte_get_timer_hz();
        if (time_inter_temp>=0.5){
            uint64_t dtx, drx;
            uint64_t dtxB, drxB;

            dtx = total_tx - last_total_tx;
            dtxB = total_txB - last_total_txB;
            drx = total_rx - last_total_rx;
            drxB = total_rxB - last_total_rxB;

            time_last_print=time_now;
            last_total_tx = total_tx;
            last_total_txB = total_txB;
            last_total_rx = total_rx;
            last_total_rxB = total_rxB;
            flowlog_timeline[lcore_id][record_count].tx_pps_t = (double)dtx/time_inter_temp;
            flowlog_timeline[lcore_id][record_count].tx_bps_t = (double)dtxB*8/time_inter_temp;
            flowlog_timeline[lcore_id][record_count].rx_pps_t = (double)drx/time_inter_temp;
            flowlog_timeline[lcore_id][record_count].rx_bps_t = (double)drxB*8/time_inter_temp;

            record_count++;
        }
    }

    // uint64_t time_interval = rte_rdtsc() - start;
    double time_interval = (double)(rte_rdtsc() - start)/rte_get_timer_hz();
    APP_LOG("lcoreID %d: run time: %lf.\n", lcore_id, time_interval);
    APP_LOG("lcoreID %d: Sent %ld pkts, received %ld pkts, TX: %lf pps, %lf bps.\n", \
            lcore_id, total_tx, total_rx, (double)total_tx/time_interval, (double)total_txB*8/time_interval);
    APP_LOG("lcoreID %d: times of loop is %ld, should send packets %ld.\n", lcore_id, loop_count, loop_count*RX_BURST_SIZE);
    tx_pkt_num[lcore_id] = total_tx;
    rx_pkt_num[lcore_id] = total_rx;
    tx_pps[lcore_id] = (double)total_tx/time_interval;
    tx_bps[lcore_id] = (double)total_txB*8/time_interval;
    rx_pps[lcore_id] = (double)total_rx/time_interval;
    rx_bps[lcore_id] = (double)total_rxB*8/time_interval;

    //print rtt
    FILE *fp;
    char rtt_file[200];
    sprintf(rtt_file, RTT_FILE, lcore_id);
    if (unlikely(access(rtt_file, 0) != 0)){
        fp = fopen(rtt_file, "a+");
        if(unlikely(fp == NULL)){
            rte_exit(EXIT_FAILURE, "Cannot open file %s\n", rtt_file);
        }
        fprintf(fp, "rtt, pkt_seq\r\n");
    }else{
        fp = fopen(rtt_file, "a+");
    }
    for (i = 0; i < PKTS_NUM; i++){
        fprintf(fp, "%lf, %d\r\n", rtt_list[i], pkt_seq_list[i]);
    }
    fclose(fp);
    printf("finish rtt log print in core %d\n", lcore_id);
}


static int
launch_one_lcore(__attribute__((unused)) void *arg){
    uint32_t lcore_id = rte_lcore_id();
	lcore_main(lcore_id);
	return 0;
}

/* Main functional part of port initialization. 8< */
static inline int
port_init(uint16_t port, uint32_t *n_lcores_p)
{
	uint16_t rx_rings = 0, tx_rings = 0;
	uint16_t nb_rxd = RX_RING_SIZE;
	uint16_t nb_txd = TX_RING_SIZE;
	int retval;
	uint16_t q;
	struct rte_eth_dev_info dev_info;
	struct rte_eth_txconf txconf;
    uint32_t n_lcores = 0;

    int i, j;


	if (!rte_eth_dev_is_valid_port(port))
		return -1;

	retval = rte_eth_dev_info_get(port, &dev_info);
	if (retval != 0) {
		printf("Error during getting device (port %u) info: %s\n",
				port, strerror(-retval));
		return retval;
	}

	if (dev_info.tx_offload_capa & RTE_ETH_TX_OFFLOAD_MBUF_FAST_FREE)
		port_conf.txmode.offloads |=
			RTE_ETH_TX_OFFLOAD_MBUF_FAST_FREE;
    
    printf("create enabled cores\n\tcores: ");
    n_lcores = 0;
    for(i = 0; i < MAX_LCORES; i++) {
        if(rte_lcore_is_enabled(i)) {
            n_lcores++;
            printf("%u ",i);
        }
    }
    printf("\n");
    *n_lcores_p = n_lcores;

    // assign each lcore some RX & TX queues and a port
    uint32_t rx_queues_per_lcore = RX_QUEUE_PER_LCORE;
    uint32_t tx_queues_per_lcore = TX_QUEUE_PER_LCORE;
    rx_rings = n_lcores * RX_QUEUE_PER_LCORE;
    tx_rings = n_lcores * TX_QUEUE_PER_LCORE;

    uint32_t rx_queue_id = 0;
    uint32_t tx_queue_id = 0;
    uint32_t vid = 0;
    for (i = 0; i < MAX_LCORES; i++) {
        if(rte_lcore_is_enabled(i)) {
            lcore_conf[i].vid = vid++;
            lcore_conf[i].n_rx_queue = rx_queues_per_lcore;
            for (j = 0; j < lcore_conf[i].n_rx_queue; j++) {
                lcore_conf[i].rx_queue_list[j] = rx_queue_id++;
            }
            lcore_conf[i].n_tx_queue = tx_queues_per_lcore;
            for (j = 0; j < lcore_conf[i].n_tx_queue; j++) {
                lcore_conf[i].tx_queue_list[j] = tx_queue_id++;
            }
            lcore_conf[i].port = enabled_port;

        }
    }

	/* Configuration the Ethernet device. */
	retval = rte_eth_dev_configure(port, rx_rings, tx_rings, &port_conf);
	if (retval != 0){
        rte_exit(EXIT_FAILURE,
                "Ethernet device configuration error: err=%d, port=%u\n", retval, port);
    }

	retval = rte_eth_dev_adjust_nb_rx_tx_desc(port, &nb_rxd, &nb_txd);
	if (retval != 0)
		return retval;

	/* Allocate and set up 1 RX queue per Ethernet port. */
	for (q = 0; q < rx_rings; q++) {
        // create mbuf pool
        printf("create mbuf pool\n");
        char name[50];
        sprintf(name,"mbuf_pool_%d",q);
        pktmbuf_pool[q] = rte_mempool_create(
            name,
            NUM_MBUFS,
            MBUF_SIZE,
            MBUF_CACHE_SIZE,
            sizeof(struct rte_pktmbuf_pool_private),
            rte_pktmbuf_pool_init, NULL,
            rte_pktmbuf_init, NULL,
            rte_socket_id(),
            0);
        if (pktmbuf_pool[q] == NULL) {
            rte_exit(EXIT_FAILURE, "cannot init mbuf_pool_%d\n", q);
        }

        retval = rte_eth_rx_queue_setup(port, q, nb_rxd,
                rte_eth_dev_socket_id(port), NULL, pktmbuf_pool[q]);
        if (retval < 0) {
            rte_exit(EXIT_FAILURE,
                "rte_eth_rx_queue_setup: err=%d, port=%u\n", retval, port);
        }
	}

	txconf = dev_info.default_txconf;
	txconf.offloads = port_conf.txmode.offloads;
	/* Allocate and set up 1 TX queue per Ethernet port. */
	for (q = 0; q < tx_rings; q++) {
		retval = rte_eth_tx_queue_setup(port, q, nb_txd,
				rte_eth_dev_socket_id(port), &txconf);
		if (retval < 0){
			rte_exit(EXIT_FAILURE,
                "rte_eth_tx_queue_setup: err=%d, port=%u\n", retval, port);
        }
	}

	/* Starting Ethernet port. 8< */
	retval = rte_eth_dev_start(port);
	/* >8 End of starting of ethernet port. */
	if (retval < 0)
		return retval;

	/* Display the port MAC address. */
	struct rte_ether_addr addr;
	retval = rte_eth_macaddr_get(port, &addr);
	if (retval != 0)
		return retval;

	printf("Port %u MAC: %02" PRIx8 " %02" PRIx8 " %02" PRIx8
			   " %02" PRIx8 " %02" PRIx8 " %02" PRIx8 "\n",
			port, RTE_ETHER_ADDR_BYTES(&addr));

	/* Enable RX in promiscuous mode for the Ethernet device. */
	retval = rte_eth_promiscuous_enable(port);
	/* End of setting RX port in promiscuous mode. */
	if (retval != 0)
		return retval;

	return 0;
}

/* >8 End of main functional part of port initialization. */


static void signal_handler(int signum)
{
    if (signum == SIGINT || signum == SIGTERM) {
        printf("\n\nSignal %d received, preparing to exit...\n", signum);
        force_quit = true;
    }
}

int main(int argc, char *argv[])
{
    unsigned nb_ports;
    unsigned lcore_id;
    int i, j;
    uint32_t n_lcores = 0;
    struct timeval timetag;

    /* Initialize the Environment Abstraction Layer (EAL). */
    int ret = rte_eal_init(argc, argv);
    if (ret < 0) rte_exit(EXIT_FAILURE, "Error with EAL initialization\n");
    argc -= ret; argv += ret;

    /* Parse app-specific arguments. */
    static const char user_opts[] = "p:";	// port_num
    int opt;
    while ((opt = getopt(argc, argv, user_opts)) != EOF) {
        switch (opt) {
        case 'p':
            if (optarg[0] == '\0') rte_exit(EXIT_FAILURE, "Invalid port\n");
            enabled_port = strtoul(optarg, NULL, 10);
            break;
        default: rte_exit(EXIT_FAILURE, "Invalid arguments\n");
        }
    }

    /* Setup signal handler. */
    force_quit = false;
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);

    /* Check that there is an even number of ports to send/receive on. */
    nb_ports = rte_eth_dev_count_avail();
    if (enabled_port >= nb_ports)
        rte_exit(EXIT_FAILURE, "Error: Specified port out-of-range\n");

    /* Initialize the ports. */
    if (port_init(enabled_port, &n_lcores) != 0)
        rte_exit(EXIT_FAILURE, "Cannot init port %u\n", enabled_port);

    /* Calculate minimum TSC diff for returning signed packets */
    min_txintv *= rte_get_timer_hz() / US_PER_S;
    printf("TSC freq: %lu Hz\n", rte_get_timer_hz());

    /* Call lcore_main on the main core only. */
    printf("core_num:%d\n",n_lcores);

    gettimeofday(&timetag, NULL);
    rte_eal_mp_remote_launch((lcore_function_t *)launch_one_lcore, NULL, CALL_MAIN);
    RTE_LCORE_FOREACH_WORKER(lcore_id){
        if (rte_eal_wait_lcore(lcore_id) < 0) {
            ret = -1;
            break;
        } 
    }

    /*output statics*/
    uint64_t total_tx_pkt_num = 0, total_rx_pkt_num = 0;
    double total_rx_pps = 0.0, total_rx_bps = 0.0;
    FILE *fp;

    if (unlikely(access(THROUGHPUT_FILE, 0) != 0)){
        fp = fopen(THROUGHPUT_FILE, "a+");
        if(unlikely(fp == NULL)){
            rte_exit(EXIT_FAILURE, "Cannot open file %s\n", THROUGHPUT_FILE);
        }
        fprintf(fp, "core,timestamp,send_pkts,rcv_pkts,send_pps,send_bps,rcv_pps,rcv_bps\r\n");
    }else{
        fp = fopen(THROUGHPUT_FILE, "a+");
    }

    for(i = 0; i < MAX_LCORES; i++){
        total_tx_pkt_num += tx_pkt_num[i];
        total_rx_pkt_num +=rx_pkt_num[i];
        total_rx_pps += rx_pps[i];
        total_rx_bps += rx_bps[i];
    }
    fprintf(fp, "%d,%ld,%ld,%ld,0,0,%lf,%lf\r\n", \
            n_lcores, timetag.tv_sec, total_tx_pkt_num, total_rx_pkt_num, total_rx_pps, total_rx_bps);
    fclose(fp);
    APP_LOG("Total Sent %ld pkts, received %ld pkts, RX: %lf pps, %lf bps.\n", \
            total_tx_pkt_num, total_rx_pkt_num, total_rx_pps, total_rx_bps);

    if (unlikely(access(THROUGHPUT_TIME_FILE, 0) != 0)){
        fp = fopen(THROUGHPUT_TIME_FILE, "a+");
        fprintf(fp, "core,timestamp,time,send_pps,send_bps,rcv_pps,rcv_bps\r\n");
    }else{
        fp = fopen(THROUGHPUT_TIME_FILE, "a+");
    }
    for (i = 0;i<MAX_RECORD_COUNT;i++){
        double rx_pps_p = 0, rx_bps_p = 0;
        for (j = 0;j<MAX_LCORES;j++){
            if(rte_lcore_is_enabled(j)) {
                rx_pps_p += flowlog_timeline[j][i].rx_pps_t;
                rx_bps_p += flowlog_timeline[j][i].rx_bps_t;
            }
        }
        fprintf(fp, "%d,%ld,%d,0,0,%lf,%lf\r\n", \
                n_lcores, timetag.tv_sec, i, rx_pps_p, rx_bps_p);
    }
    fclose(fp);

    for (j = 0;j<MAX_LCORES;j++){
        if(rte_lcore_is_enabled(j)) {
            free(flowlog_timeline[j]);
        }
    }

    /* Cleaning up. */
    fflush(stdout);
APP_RTE_CLEANUP:
    printf("Closing port %u... ", enabled_port);
    rte_eth_dev_stop(enabled_port);
    rte_eth_dev_close(enabled_port);
    printf("Done.\n");

    return 0;
}
