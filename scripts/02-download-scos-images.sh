curl -L -o scos.qcow2.gz "$(./openshift-install coreos print-stream-json | jq -r '.architectures.x86_64.artifacts.qemu.formats."qcow2.gz".disk.location')"
