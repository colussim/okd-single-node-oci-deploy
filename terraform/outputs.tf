############################################
# Datas to retrieve information from the primary VNIC
############################################

# A VNIC attachments for the instance
data "oci_core_vnic_attachments" "this" {
  compartment_id = var.compartment_ocid
  instance_id    = oci_core_instance.odk_instance.id
}

# Primary VNIC
data "oci_core_vnic" "primary" {
  vnic_id = data.oci_core_vnic_attachments.this.vnic_attachments[0].vnic_id
}

############################################
# Outputs 
############################################

# Private IP (directly from VNIC)
output "sno_private_ip" {
  value = data.oci_core_vnic.primary.private_ip_address
}

# Public IP (ephemeral) if assigned to VNIC
output "sno_public_ip" {
  value = data.oci_core_vnic.primary.public_ip_address
}

# VNIC MAC address (useful for Assisted Installer)
output "sno_mac_address" {
  value = data.oci_core_vnic.primary.mac_address
}

# OCID subnet
output "sno_subnet_id" {
  value = oci_core_subnet.sno_subnet.id
}

# OCID NSG
output "sno_nsg_id" {
  value = oci_core_network_security_group.sno_nsg.id
}

# SSH command ready to paste (core user)
output "ssh_core_cmd" {
  value = "ssh core@${data.oci_core_vnic.primary.public_ip_address}"
}