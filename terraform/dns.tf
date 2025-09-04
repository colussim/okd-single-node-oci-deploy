locals {
  # Exemple: okdk8s.mysqllab.com
  cluster_zone_fqdn = "${var.cluster_subdomain}.${var.domain}"
}

#########################
# 1) Private DNS View
#########################
resource "oci_dns_view" "mysqllab_view" {
  compartment_id = var.compartment_ocid
  display_name   = "view-${var.domain}"
  scope          = "PRIVATE"
}

##############################################
# 2) Attach the View to the VCN resolver
##############################################
data "oci_core_vcn_dns_resolver_association" "this" {
  vcn_id = var.vcn_ocid
}

resource "oci_dns_resolver" "vcn_resolver" {
  resolver_id = data.oci_core_vcn_dns_resolver_association.this.dns_resolver_id

  attached_views {
    view_id = oci_dns_view.mysqllab_view.id
  }
}

##############################################
# 3) Private Zone: "<cluster_subdomain>.<domain>"
##############################################
resource "oci_dns_zone" "cluster_zone" {
  compartment_id = var.compartment_ocid
  name           = local.cluster_zone_fqdn
  zone_type      = "PRIMARY"
  scope          = "PRIVATE"
  view_id        = oci_dns_view.mysqllab_view.id

  depends_on = [
    oci_dns_resolver.vcn_resolver
  ]
}

##############################################
# 4) RRsets required for SNO OKD
#    All point to the node's IP: var.node_ip
##############################################

# A api.<zone> -> node_ip
resource "oci_dns_rrset" "api_a" {
  zone_name_or_id = oci_dns_zone.cluster_zone.id
  domain          = "api.${local.cluster_zone_fqdn}"
  rtype           = "A"
  scope           = "PRIVATE"
  view_id         = oci_dns_view.mysqllab_view.id

  items {
    domain = "api.${local.cluster_zone_fqdn}"
    rtype  = "A"
    rdata  = var.node_ip
    ttl    = 60
  }

  depends_on = [oci_dns_zone.cluster_zone]
}

# A api-int.<zone> -> node_ip
resource "oci_dns_rrset" "api_int_a" {
  zone_name_or_id = oci_dns_zone.cluster_zone.id
  domain          = "api-int.${local.cluster_zone_fqdn}"
  rtype           = "A"
  scope           = "PRIVATE"
  view_id         = oci_dns_view.mysqllab_view.id

  items {
    domain = "api-int.${local.cluster_zone_fqdn}"
    rtype  = "A"
    rdata  = var.node_ip
    ttl    = 60
  }

  depends_on = [oci_dns_zone.cluster_zone]
}

# A *.apps.<zone> -> node_ip
resource "oci_dns_rrset" "apps_wildcard_a" {
  zone_name_or_id = oci_dns_zone.cluster_zone.id
  domain          = "*.apps.${local.cluster_zone_fqdn}"
  rtype           = "A"
  scope           = "PRIVATE"
  view_id         = oci_dns_view.mysqllab_view.id

  items {
    domain = "*.apps.${local.cluster_zone_fqdn}"
    rtype  = "A"
    rdata  = var.node_ip
    ttl    = 60
  }

  depends_on = [oci_dns_zone.cluster_zone]
}