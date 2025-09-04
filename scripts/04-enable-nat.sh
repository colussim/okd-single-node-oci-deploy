sudo iptables -t nat -A POSTROUTING -s 10.0.30.0/24 -o <internet_iface> -j MASQUERADE
sudo sysctl -w net.ipv4.ip_forward=1
