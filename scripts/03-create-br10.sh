sudo nmcli connection add type bridge ifname br10 con-name br10
sudo nmcli connection modify br10 ipv4.addresses 10.0.30.1/24 ipv4.method manual
sudo nmcli connection up br10
