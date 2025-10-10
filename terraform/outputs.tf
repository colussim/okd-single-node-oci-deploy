

# Subnet ID (adopt-or-create)
output "sno_subnet_id" {
  value       = local.sno_subnet_id
  description = "OCID of the subnet used by the SNO instance"
}

# IP privée du SNO (depuis le VNIC primaire)
output "sno_private_ip" {
  value       = data.oci_core_vnic.primary.private_ip_address
  description = "Adresse IP privée de l'instance SNO"
}

# IP publique du SNO (si assignée)
output "sno_public_ip" {
  value       = data.oci_core_vnic.primary.public_ip_address
  description = "Adresse IP publique de l'instance SNO (si assignée)"
}


# Commande SSH (user core)
output "ssh_core_cmd" {
  value       = "ssh ${var.ssh_user}@${data.oci_core_vnic.primary.public_ip_address}"
  description = "Commande SSH vers le noeud"
}

# FQDNs 
output "api_fqdn" {
  value       = "api.${var.cluster_subdomain}.${var.domain}"
  description = "FQDN de l'API OpenShift"
}

output "apps_wildcard_fqdn" {
  value       = "*.apps.${var.cluster_subdomain}.${var.domain}"
  description = "Wildcard apps du cluster"
}

output "started_at" {
  value = null_resource.start_clock.triggers.started_at
}

output "finished_at" {
  value = null_resource.end_clock.triggers.finished_at
}