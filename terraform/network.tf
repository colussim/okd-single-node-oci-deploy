
locals {
  rt_id_for_subnet = var.create_igw ? oci_core_route_table.rt_public[0].id : var.route_table_id
}

# Internet Gateway 
resource "oci_core_internet_gateway" "igw" {
  count          = var.create_igw ? 1 : 0
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_ocid
  display_name   = "vcn-igw"
  enabled        = true
}

# Route table publique 
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

# DHCP Options 
resource "oci_core_dhcp_options" "dhcp" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_ocid
  display_name   = "sno-dhcp"

  options {
    type        = "DomainNameServer"
    server_type = "VcnLocalPlusInternet"
  }

  options {
    type                = "SearchDomain"
    search_domain_names = ["${var.cluster_subdomain}.${var.domain}"]
  }
}

# --- Subnet SNO (ex: 10.0.30.0/24) ---
resource "oci_core_subnet" "sno_subnet" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = var.vcn_ocid
  cidr_block                 = var.subnet_cidr # "10.0.30.0/24"
  display_name               = "sno-subnet-10-0-30-0-24"
  dhcp_options_id            = oci_core_dhcp_options.dhcp.id
  route_table_id             = local.rt_id_for_subnet 
  prohibit_public_ip_on_vnic = false                  
  dns_label                  = var.subnet_dns_label   
}