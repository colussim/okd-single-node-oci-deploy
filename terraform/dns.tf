locals {
  cluster_zone_fqdn = "${var.cluster_subdomain}.${var.domain}"
  create_view       = var.existing_private_view_id == "" ? true : false
  create_zone       = var.existing_private_zone_id == "" ? true : false
}

###########################################
# 1) Private DNS View (create-or-reuse)
###########################################
resource "oci_dns_view" "view" {
  count         = local.create_view ? 1 : 0
  compartment_id = var.compartment_ocid
  display_name   = "view-${var.domain}"
  scope          = "PRIVATE"
}

######################################################################
# 2) Attach the View to the VCN resolver (only if we created the view)
######################################################################
data "oci_core_vcn_dns_resolver_association" "assoc" {
  vcn_id = var.vcn_ocid
}

resource "oci_dns_resolver" "vcn_resolver" {
  count       = local.create_view ? 1 : 0
  resolver_id = data.oci_core_vcn_dns_resolver_association.assoc.dns_resolver_id

  attached_views {
    view_id = oci_dns_view.view[0].id
  }
}

# pointer to the view to use (created or existing)
locals {
  view_id = local.create_view ? oci_dns_view.view[0].id : var.existing_private_view_id
}

######################################################################
# 3) Private Zone "<cluster_subdomain>.<domain>" (create-or-reuse)
######################################################################
resource "oci_dns_zone" "cluster_zone" {
  count          = local.create_zone ? 1 : 0
  compartment_id = var.compartment_ocid
  name           = local.cluster_zone_fqdn
  zone_type      = "PRIMARY"
  scope          = "PRIVATE"
  view_id        = local.view_id

  depends_on = [
    oci_dns_resolver.vcn_resolver
  ]
}

# Pointer to the area to be used (created or existing)
locals {
  zone_id = local.create_zone ? oci_dns_zone.cluster_zone[0].id : var.existing_private_zone_id
}

##############################################
# 4) RRsets for SNO OKD -> var.node_ip
##############################################

# A api.<zone> -> node_ip
resource "oci_dns_rrset" "api_a" {
  zone_name_or_id = local.zone_id
  domain          = "api.${local.cluster_zone_fqdn}."
  rtype           = "A"
  scope           = "PRIVATE"
  view_id         = local.view_id

  items {
    domain = "api.${local.cluster_zone_fqdn}."
    rtype  = "A"
    rdata  = var.node_ip
    ttl    = 60
  }
}

# A api-int.<zone> -> node_ip
resource "oci_dns_rrset" "api_int_a" {
  zone_name_or_id = local.zone_id
  domain          = "api-int.${local.cluster_zone_fqdn}."
  rtype           = "A"
  scope           = "PRIVATE"
  view_id         = local.view_id

  items {
    domain = "api-int.${local.cluster_zone_fqdn}."
    rtype  = "A"
    rdata  = var.node_ip
    ttl    = 60
  }
}


# A *.apps.<zone> -> node_ip
resource "oci_dns_rrset" "apps_wildcard_a" {
  zone_name_or_id = local.zone_id
  domain          = "*.apps.${local.cluster_zone_fqdn}."
  rtype           = "A"
  scope           = "PRIVATE"
  view_id         = local.view_id

  items {
    domain = "*.apps.${local.cluster_zone_fqdn}."
    rtype  = "A"
    rdata  = var.node_ip
    ttl    = 60
  }
}