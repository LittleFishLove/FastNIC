/* SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2017 Mellanox Technologies, Ltd
 */

#include "flow_rules.h"
#include "para.h"

/**
 * create a flow rule that sends packets with matching src and dest ip
 * to selected queue.
 *
 * @param port_id
 *   The selected port.
 * @param rx_q
 *   The selected target queue.
 * @param src_ip
 *   The src ip value to match the input packet.
 * @param src_mask
 *   The mask to apply to the src ip.
 * @param dest_ip
 *   The dest ip value to match the input packet.
 * @param dest_mask
 *   The mask to apply to the dest ip.
 * @param[out] error
 *   Perform verbose error reporting if not NULL.
 *
 * @return
 *   A flow if the rule could be created else return NULL.
 */

/* Function responsible for creating the flow rule. 8< */
struct rte_flow *
generate_ipv4_flow(uint16_t port_id, uint16_t rx_q,
		uint32_t src_ip, uint32_t src_mask,
		uint32_t dest_ip, uint32_t dest_mask,
		struct rte_flow_error *error)
{
	/* Declaring structs being used. 8< */
	struct rte_flow_attr attr;
	struct rte_flow_item pattern[IPV4_PATTERN_NUM];
	struct rte_flow_action action[IPV4_ACTION_NUM];
	struct rte_flow *flow = NULL;
	struct rte_flow_action_queue queue = { .index = rx_q };
	struct rte_flow_item_ipv4 ip_spec;
	struct rte_flow_item_ipv4 ip_mask;
	/* >8 End of declaring structs being used. */
	int res;

	memset(pattern, 0, sizeof(pattern));
	memset(action, 0, sizeof(action));

	/* Set the rule attribute, only ingress packets will be checked. 8< */
	memset(&attr, 0, sizeof(struct rte_flow_attr));
	attr.ingress = 1;
	/* >8 End of setting the rule attribute. */

	/*
	 * create the action sequence.
	 * one action only,  move packet to queue
	 */
	action[0].type = RTE_FLOW_ACTION_TYPE_QUEUE;
	action[0].conf = &queue;
	action[1].type = RTE_FLOW_ACTION_TYPE_END;

	/*
	 * set the first level of the pattern (ETH).
	 * since in this example we just want to get the
	 * ipv4 we set this level to allow all.
	 */

	/* Set this level to allow all. 8< */
	pattern[0].type = RTE_FLOW_ITEM_TYPE_ETH;
	/* >8 End of setting the first level of the pattern. */

	/*
	 * setting the second level of the pattern (IP).
	 * in this example this is the level we care about
	 * so we set it according to the parameters.
	 */

	/* Setting the second level of the pattern. 8< */
	memset(&ip_spec, 0, sizeof(struct rte_flow_item_ipv4));
	memset(&ip_mask, 0, sizeof(struct rte_flow_item_ipv4));
	ip_spec.hdr.dst_addr = htonl(dest_ip);
	ip_mask.hdr.dst_addr = dest_mask;
	ip_spec.hdr.src_addr = htonl(src_ip);
	ip_mask.hdr.src_addr = src_mask;
	pattern[1].type = RTE_FLOW_ITEM_TYPE_IPV4;
	pattern[1].spec = &ip_spec;
	pattern[1].mask = &ip_mask;
	/* >8 End of setting the second level of the pattern. */

	/* The final level must be always type end. 8< */
	pattern[2].type = RTE_FLOW_ITEM_TYPE_END;
	/* >8 End of final level must be always type end. */

	/* Validate the rule and create it. 8< */
	res = rte_flow_validate(port_id, &attr, pattern, action, error);
	if (!res)
		flow = rte_flow_create(port_id, &attr, pattern, action, error);
	/* >8 End of validation the rule and create it. */

	return flow;
}
/* >8 End of function responsible for creating the flow rule. */


/* Function responsible for creating the flow rule. 8< */
struct rte_flow *
generate_ipv4_udp_flow(uint16_t port_id, uint16_t rx_q,
		uint32_t src_ip, uint32_t src_mask,
		uint32_t dest_ip, uint32_t dest_mask,
		uint16_t udp_src_port, uint16_t udp_dst_port,
		struct rte_flow_error *error)
{
	/* Declaring structs being used. 8< */
	struct rte_flow_attr attr;
	struct rte_flow_item pattern[IPV4_UDP_PATTERN_NUM];
	struct rte_flow_action action[IPV4_UDP_ACTION_NUM];
	struct rte_flow *flow = NULL;
	struct rte_flow_action_count counter = { .id = 1 };
	struct rte_flow_action_queue queue = { .index = rx_q };
	struct rte_flow_item_ipv4 ip_spec;
	struct rte_flow_item_ipv4 ip_mask;
	struct rte_flow_item_udp udp_port_spec;
	struct rte_flow_item_udp udp_port_mask;
	/* >8 End of declaring structs being used. */
	int res;

	memset(pattern, 0, sizeof(pattern));
	memset(action, 0, sizeof(action));

	/* Set the rule attribute, only ingress packets will be checked. 8< */
	memset(&attr, 0, sizeof(struct rte_flow_attr));
	attr.priority = 0;
	attr.ingress = 1;
	attr.group = GROUP_ID;
	/* >8 End of setting the rule attribute. */

	/*
	 * create the action sequence.
	 * one action only,  move packet to queue
	 */
	action[0].type = RTE_FLOW_ACTION_TYPE_COUNT;
	action[0].conf = &counter;
	action[1].type = RTE_FLOW_ACTION_TYPE_QUEUE;
	action[1].conf = &queue;
	action[2].type = RTE_FLOW_ACTION_TYPE_END;

	/*
	 * set the first level of the pattern (ETH).
	 * since in this example we just want to get the
	 * ipv4 we set this level to allow all.
	 */

	/* Set this level to allow all. 8< */
	pattern[0].type = RTE_FLOW_ITEM_TYPE_ETH;
	/* >8 End of setting the first level of the pattern. */

	/*
	 * setting the second level of the pattern (IP).
	 * in this example this is the level we care about
	 * so we set it according to the parameters.
	 */

	/* Setting the second level of the pattern. 8< */
	memset(&ip_spec, 0, sizeof(struct rte_flow_item_ipv4));
	memset(&ip_mask, 0, sizeof(struct rte_flow_item_ipv4));
	ip_spec.hdr.dst_addr = htonl(dest_ip);
	ip_mask.hdr.dst_addr = dest_mask;
	ip_spec.hdr.src_addr = htonl(src_ip);
	ip_mask.hdr.src_addr = src_mask;
	pattern[1].type = RTE_FLOW_ITEM_TYPE_IPV4;
	pattern[1].spec = &ip_spec;
	pattern[1].mask = &ip_mask;
	/* >8 End of setting the second level of the pattern. */

	/* Setting the third level of the pattern. 8< */
	memset(&udp_port_spec, 0, sizeof(struct rte_flow_item_udp));
	memset(&udp_port_mask, 0, sizeof(struct rte_flow_item_udp));
	udp_port_spec.hdr.dst_port = udp_dst_port;
	udp_port_spec.hdr.src_port = udp_src_port;
	udp_port_mask.hdr.dst_port = 0xffff;
	udp_port_mask.hdr.src_port = 0xffff;
	pattern[2].type = RTE_FLOW_ITEM_TYPE_UDP;
	pattern[2].spec = &udp_port_spec;
	pattern[2].mask = &udp_port_mask;

	/* >8 End of setting the third level of the pattern. */

	/* The final level must be always type end. 8< */
	pattern[3].type = RTE_FLOW_ITEM_TYPE_END;
	/* >8 End of final level must be always type end. */

	/* Validate the rule and create it. 8< */
	res = rte_flow_validate(port_id, &attr, pattern, action, error);
	if (!res)
		flow = rte_flow_create(port_id, &attr, pattern, action, error);

	/* >8 End of validation the rule and create it. */

	return flow;
}
/* >8 End of function responsible for creating the flow rule. */

/* Function responsible for creating the flow rule. 8< */
/* simulating OVS */
static struct rte_flow *
flow_create_bf3(uint16_t port_id, struct rte_flow_attr *attr,
		struct offload_pattern *header, struct offload_pattern *mask,
		struct offload_action *action_args,
		struct rte_flow_error *error, uint64_t *add_cycle)
{
	/* Declaring structs being used. 8< */
	struct rte_flow_item pattern[BF3_FORWARD_PATTERN_NUM];
	struct rte_flow_action action[BF3_FORWARD_ACTION_NUM];
	struct rte_flow *flow = NULL;
	uint64_t start;

	int res;

	memset(pattern, 0, sizeof(pattern));
	memset(action, 0, sizeof(action));

	/* generate patterns */
	pattern[0].type = RTE_FLOW_ITEM_TYPE_ETH;
	struct rte_flow_item_eth eth_spec;
	struct rte_flow_item_eth eth_mask;
	memset(&eth_spec, 0, sizeof(struct rte_flow_item_eth));
	memset(&eth_mask, 0, sizeof(struct rte_flow_item_eth));
	// eth_spec.hdr.ether_type = 8;
	// eth_spec.has_vlan = 0;
	// eth_mask.hdr.ether_type = 65535;
	// eth_spec.has_vlan = 1;
	pattern[0].spec = &eth_spec;
	pattern[0].mask = &eth_mask;

	pattern[1].type = RTE_FLOW_ITEM_TYPE_IPV4;
	struct rte_flow_item_ipv4 ipv4_spec;
	struct rte_flow_item_ipv4 ipv4_mask;
	memset(&ipv4_spec, 0, sizeof(struct rte_flow_item_ipv4));
	memset(&ipv4_mask, 0, sizeof(struct rte_flow_item_ipv4));
	ipv4_spec.hdr.src_addr = header->ipv4_src;
	ipv4_mask.hdr.src_addr = mask->ipv4_src;
	pattern[1].spec = &ipv4_spec;
	pattern[1].mask = &ipv4_mask;

	pattern[2].type = RTE_FLOW_ITEM_TYPE_END;

	/* generate actions */
	action[0].type = RTE_FLOW_ACTION_TYPE_COUNT;
	struct rte_flow_action_count counter;
	counter.id = action_args->counter_id;
	action[0].conf = &counter;

	action[1].type = RTE_FLOW_ACTION_TYPE_PORT_ID;
	struct rte_flow_action_port_id forward;
	forward.original = 0;
	forward.reserved = 0;
	forward.id = action_args->port_id;
	action[1].conf = &forward;

	action[2].type = RTE_FLOW_ACTION_TYPE_END;

	/* Validate the rule and create it. 8< */
	res = rte_flow_validate(port_id, attr, pattern, action, error);
	if (!res){
		start = rte_rdtsc();
		flow = rte_flow_create(port_id, attr, pattern, action, error);
		*add_cycle = rte_rdtsc() - start;
	}
	/* >8 End of validation the rule and create it. */

	return flow;
}


/** Function responsible for creating the flow rule.
 * simulating OVS 
 * add rules in_port=dpdk_p0,ip_src=$ip_dot,actions=output:dpdk_p0hpf */

void
one_flow_install_bf3(void)
{
	uint16_t in_port_id = 0;

	struct rte_flow_attr attr;
	struct offload_pattern header;
	struct offload_pattern mask;
	struct offload_action action_args;
	struct rte_flow_error error;

	memset(&attr, 0, sizeof(struct rte_flow_attr));
	attr.group = GROUP_ID;
	attr.priority = 0;
	attr.ingress = 0;
	attr.egress = 0;
	attr.transfer = 1;

	uint32_t ip_src;
	inet_pton(AF_INET, "192.0.0.0", &ip_src);
	header.ipv4_src = ip_src;

	uint32_t ip_src_mask;
	inet_pton(AF_INET, "255.255.255.255", &ip_src_mask);
	mask.ipv4_src = ip_src_mask;

	action_args.counter_id = 0;
	action_args.port_id = 1;
	
	struct rte_flow *flow = NULL;
	uint64_t add_cycle;
	flow = flow_create_bf3(in_port_id, &attr, &header, &mask, &action_args, &error, &add_cycle);
	double add_time = (double) add_cycle / rte_get_timer_hz();
	if (!flow) {
		printf("Flow can't be created %d message: %s\n",
			    error.type,
			    error.message ? error.message : "(no stated reason)");
	}
	else{
		printf("already add 1 flow, add cycle is %ld, add time is %lf\n", add_cycle, add_time);
	}
}

