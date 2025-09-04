export LIBVIRT_DEFAULT_URI=qemu:///system
sudo virt-install \
  --name okd-sno \
  --ram 32768 \
  --vcpus 8 \
  --cpu host-model \
  --os-variant rhel9.0 \
  --disk path=/data02/okd-agent/okd-sno.qcow2,format=qcow2,bus=virtio \
  --cdrom /data/okd/workdir/agent.x86_64.iso \
  --network network=okd-net,model=virtio,mac=52:54:00:12:34:56 \
  --graphics none \
  --noautoconsole
