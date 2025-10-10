qemu-img convert -f qcow2 -O vmdk \
  -o subformat=streamOptimized,compat6 \
  /data02/okd-agent/okd-sno.qcow2 \
  /data02/scos-okd-sno/okd-sno.vmdk
