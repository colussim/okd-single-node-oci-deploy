locals {
  rt_id_for_subnet = var.create_igw ? oci_core_route_table.rt_public[0].id : var.route_table_id
}

# Internet Gateway (optional)
resource "oci_core_internet_gateway" "igw" {
  count          = var.create_igw ? 1 : 0
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_ocid
  display_name   = "vcn-igw"
  enabled        = true
}

# Public table route (if IGW created)
resource "oci_core_route_table" "rt_public" {
  count          = var.create_igw ? 1 : 0
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_ocid
  display_name   = "rt-public"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw[0].id
    description       = "Internet access"
  }
}

# DHCP Options (Custom DNS if provided, otherwise default VCN resolver)
resource "oci_core_dhcp_options" "dhcp" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_ocid
  display_name   = "sno-dhcp"

  # If DNS are provided -> CustomDNServer
  dynamic "options" {
    for_each = length(var.dns_servers) > 0 ? [1] : []
    content {
      type               = "DomainNameServer"
      server_type        = "CustomDnsServer"       
      custom_dns_servers = var.dns_servers
    }
  }

  # If not   -> VcnLocalPlusInternet
  dynamic "options" {
    for_each = length(var.dns_servers) == 0 ? [1] : []
    content {
      type        = "DomainNameServer"
      server_type = "VcnLocalPlusInternet"
    }
  }

  # Search domain: <cluster_subdomain>.<domain>
  options {
    type                = "SearchDomain"
    search_domain_names = ["${var.cluster_subdomain}.${var.domain}"]
  }
}

# --- Adopt-or-Create ---
data "oci_core_subnets" "all_in_vcn" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_ocid
}

locals {
  wanted_cidr      = var.subnet_cidr                 
  wanted_name      = "sno-subnet-10-0-30-0-24"     
  wanted_dns_label = var.subnet_dns_label          
  matching_subnets = [
    for s in data.oci_core_subnets.all_in_vcn.subnets : s
    if s.cidr_block == local.wanted_cidr
      || try(s.display_name, "") == local.wanted_name
      || try(s.dns_label, "") == local.wanted_dns_label
  ]

  sno_already_exists = length(local.matching_subnets) > 0
  existing_sno_id    = local.sno_already_exists ? local.matching_subnets[0].id : null
}

# Subnet SNO (created only if absent)
resource "oci_core_subnet" "sno_subnet" {
  count                      = local.sno_already_exists ? 0 : 1
  compartment_id             = var.compartment_ocid
  vcn_id                     = var.vcn_ocid
  cidr_block                 = var.subnet_cidr
  display_name               = local.wanted_name
  dhcp_options_id            = oci_core_dhcp_options.dhcp.id
  route_table_id             = local.rt_id_for_subnet
  prohibit_public_ip_on_vnic = false
  dns_label                  = var.subnet_dns_label
}

# subnet ID to be reused in compute.tf
locals {
  sno_subnet_id = local.sno_already_exists ? local.existing_sno_id : oci_core_subnet.sno_subnet[0].id
}