import socket
import sys

def main():
    script_name = sys.argv[0]
    rule_num = int(sys.argv[1])
    ip_prefix = 10 << 24
    file.write("flow create 0 group 0 ingress pattern eth / end actions jump group 1 / end")

    with open("./rule_testpmd.txt", "w") as file:
        for i in range(rule_num):
            src_ip = socket.inet_ntoa((ip_prefix + i).to_bytes(4, byteorder='big'))
            file.write("flow create 0 group 1 ingress pattern eth / ipv4 src is " + src_ip + " / tcp / end actions set_ipv4_dst ipv4_addr 2.2.2.2 / queue index 5 / count / end" + "\n") 

if __name__ == "__main__":
    main()