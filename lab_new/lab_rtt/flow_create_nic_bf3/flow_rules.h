#ifndef FLOW_RULES_H
#define FLOW_RULES_H

#include <stdint.h>
#include <rte_flow.h>

#define IPV4_PATTERN_NUM 3
#define IPV4_ACTION_NUM 2

#define IPV4_UDP_PATTERN_NUM 4
#define IPV4_UDP_ACTION_NUM 3

#define BF3_FORWARD_PATTERN_NUM 3
#define BF3_FORWARD_ACTION_NUM 3


struct offload_pattern {
	rte_be32_t ipv4_src;
};

struct offload_action {
	uint32_t counter_id;
	uint32_t port_id;
};

struct rte_flow *
generate_ipv4_flow(uint16_t port_id, uint16_t rx_q,
		uint32_t src_ip, uint32_t src_mask,
		uint32_t dest_ip, uint32_t dest_mask,
		struct rte_flow_error *error);
struct rte_flow *
generate_ipv4_udp_flow(uint16_t port_id, uint16_t rx_q,
		uint32_t src_ip, uint32_t src_mask,
		uint32_t dest_ip, uint32_t dest_mask,
		uint16_t udp_src_port, uint16_t udp_dst_port,
		struct rte_flow_error *error);
void one_flow_install_bf3(void);
#endif
