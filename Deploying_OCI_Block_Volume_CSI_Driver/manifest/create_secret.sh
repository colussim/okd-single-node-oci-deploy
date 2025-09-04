kubectl -n kube-system create secret generic oci-volume-provisioner \
  --from-file=config.yaml=provider-config.yaml
