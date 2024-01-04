import socket
import sys

def main():
    script_name = sys.argv[0]
    rule_num = sys.argv[1]
    ip_prefix = 10 << 24
    command_template = "flow create 0 group 0 transfer pattern eth / ipv4 src is 10.0.0.0 / tcp / end actions port_id id 1 / count / end"

    with open("./rule_testpmd.txt", "w") as file:
        for i in range(rule_num):
            src_ip = socket.inet_ntoa((ip_prefix + i).to_bytes(4, byteorder='big'))
            file.write("flow create 0 group 0 transfer pattern eth / ipv4 src is " + src_ip + " / tcp / end actions port_id id 1 / count / end" + "\n") 

if __name__ == "__main__":
    main()