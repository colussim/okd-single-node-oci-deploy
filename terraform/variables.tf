// ============ General / Identity ============
variable "region" {
  type        = string
  description = "Oracle Cloud region"
  default     = "us-ashburn-1"
}

variable "compartment_ocid" {
  type        = string
  description = "Compartment OCID where resources are created"
  default     = "ocid1.compartment.oc1..xxxxxxx"
}


variable "tenancy_ocid" {
  type        = string
  description = "tenancy_ocid"
  default ="ocid1.tenancy.oc1..xxxxx"
} 

// ============ Networking ============
variable "vcn_ocid" {
  type        = string
  description = "Existing VCN OCID (subnet will be created inside this VCN)"
  default     = "ocid1.vcn.oc1.iad.xxxxxxx"
}

variable "subnet_cidr" {
  type        = string
  description = "CIDR of the subnet to create for the SNO node (must match install-config machineNetwork)"
  default     = "10.0.30.0/24"
}

variable "subnet_dns_label" {
  type        = string
  description = "DNS label for the subnet"
  default     = "sno30"
}

variable "dns_servers" {
  type        = list(string)
  description = "Custom DNS servers for the subnet (optional)"
  default     = ["10.0.30.2"]
}

variable "create_igw" {
  type        = bool
  description = "Create an Internet Gateway for egress (if false, provide route_table_id)"
  default     = false
}

variable "route_table_id" {
  type        = string
  description = "Existing route table OCID to attach to the subnet when create_igw = false"
  default     = ""
}

variable "admin_cidr" {
  type        = string
  description = "CIDR allowed to access the node (SSH/API as needed)"
  default     = "0.0.0.0/0"
}

// Optional: attach NSGs if you have them
variable "nsg_ids" {
  type        = list(string)
  description = "Optional list of NSG OCIDs to attach to the VNIC"
  default     = []
}

// ============ Compute ============
variable "shape" {
  type        = string
  description = "Instance shape (use E5.* for amd64, A1.Flex for arm64)"
  default     = "VM.Standard.E5.Flex"
}

variable "arch" {
  type        = string
  description = "Target CPU architecture: amd64 or arm64"
  default     = "amd64"

  validation {
    condition     = contains(["amd64", "arm64"], var.arch)
    error_message = "arch must be 'amd64' or 'arm64'."
  }
}

variable "ocpus" {
  type        = number
  description = "Number of OCPUs"
  default     = 8
}

variable "memory_gbs" {
  type        = number
  description = "Memory in GB"
  default     = 32
}

variable "boot_gb" {
  type        = number
  description = "Boot volume size in GB"
  default     = 900
}

// Base Linux image (Oracle Linux/Fedora Cloud) used to run coreos-installer at first boot
variable "base_linux_image_ocid" {
  type        = string
  description = "OCID of base Linux image to boot (not SCOS). VM will reimage itself via coreos-installer."
  default     = "ocid1.image.oc1.iad.aaaaaaaazqak7q2gzmnomqpnlpqzwg27wovlo4z5beoftmfhc2h6owaowflq"
}

variable "okd_bucket_name"      { 
  type = string
  description = "okd-images"
  default="okd-images"

}

variable "okd_ignition_object"  { 
  type = string
  description = "bootstrap-in-place-for-live-iso.ign" 
  default = "images/scos/okdk8s-02/bootstrap-in-place-for-live-iso.ign"
  
}

// ============ SCOS Release ============
variable "scos_stream" {
  description = "Stream SCOS (ex: c10s)"
  type        = string
  default     = "c10s"
}

variable "scos_build" {
  description = "Build SCOS (ex: 10.0.20250628-0)"
  type        = string
  default     = "10.0.20250628-0"
}

variable "scos_arch" {
  description = "Architecture (x86_64, aarch64)"
  type        = string
  default     = "x86_64"
}

// ============ Instance Identity ============
variable "instance_name" {
  type        = string
  description = "Instance display name"
  default     = "odk02"
}

variable "hostname_label" {
  type        = string
  description = "VNIC hostname label (DNS)"
  default     = "okd02"
}

variable "node_ip" {
  type        = string
  description = "Static private IP to assign to the node (must be inside subnet_cidr)"
  default     = "10.0.30.51"
}

variable "ssh_user" {
  type        = string
  description = "Default SSH user (SCOS: 'core')"
  default     = "core"
}

variable "ssh_authorized_keys" {
  type        = string
  description = "Public SSH keys (one per line) to inject into instance metadata"
  default     = "ssh-ed25519 xxxxxxx"
}

variable "ssh_private_key" {
  type        = string
  description = "Local path to the SSH private key (if used by provisioners/scripts)"
  default     = "~/.ssh/okd-sno"
}

// ============ DNS (Private Zone: create-or-reuse) ============
variable "domain" {
  type        = string
  description = "Base domain (e.g., mysqllab.com)"
  default     = "mysqllab.com"
}

variable "cluster_subdomain" {
  type        = string
  description = "Cluster subdomain (e.g., okdk8s); FQDNs will be api.<sub>.<domain> and *.apps.<sub>.<domain>"
  default     = "okdk8s-02"
}

variable "existing_private_zone_id" {
  type        = string
  description = "If set, reuse this private DNS zone ID; if empty, Terraform creates the zone named 'domain'."
  default     = ""
}

variable "existing_private_view_id" {
  type        = string
  description = "If set, reuse this private DNS view ID; if empty, Terraform creates a new private view and attaches it to the VCN resolver."
  default     = ""
}


// ============ Kubeconfig context (futur oprtion) ============
variable "kube_context" {
  type        = string
  description = "Name to use for kubeconfig context (optional)"
  default     = "okd02"
}


// If true, Terraform will wipe any existing partitions, filesystems,
// or LVM volumes on the target disk before running the CoreOS installer.
variable "allow_wipe" {
  type        = bool
  description = "Allow the target disk to be erased BEFORE kexec"
  default     = true
}

// Block device path to install the OKD/SCOS node on.
// This should point to the raw disk (e.g. "/dev/sda") and NOT a partition (e.g. "/dev/sda3").

// The installer will repartition and format this disk according to the
// bootstrap-in-place process, so ensure it is dedicated for the cluster.
variable "installation_disk" {
  type        = string
  description = "Installation disk for bootstrapInPlace.installationDisk"
  default     = "/dev/sda"
}