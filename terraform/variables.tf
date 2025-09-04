// CIDR block allowed for admin access (SSH/kubelet)
variable "admin_cidr" {
  description = "CIDR allowed for admin (SSH/kubelet)"
  default     = "0.0.0.0/0"
}

// OCID of the compartment where resources will be created
variable "compartment_ocid" {
  type        = string
  description = "OCID of the compartment for resource creation"
  default     = "ocid1.compartment.XXXXXXXXXXXXX"
}

// OCID of the Virtual Cloud Network (VCN)
variable "vcn_ocid" {
  type        = string
  description = "OCID of the Virtual Cloud Network (VCN)"
  default     = "ocid1.vcn.XXXXXXXXXXXXXXXXXX"
}

// Oracle Cloud region for deployment
variable "region" {
  type        = string
  description = "Oracle Cloud region for deployment"
  default     = "us-ashburn-1"
}

// CIDR block for the subnet
variable "subnet_cidr" {
  type        = string
  description = "CIDR block for the subnet"
  default     = "10.0.30.0/24"
}

// DNS label for the subnet
variable "subnet_dns_label" {
  type        = string
  description = "DNS label for the subnet"
  default     = "sno30"
}

// List of DNS servers for the subnet
variable "dns_servers" {
  type        = list(string)
  description = "List of DNS servers for the subnet"
  default     = ["10.0.30.2"]
}

// Whether to create an Internet Gateway (IGW)
variable "create_igw" {
  type        = bool
  description = "Whether to create an Internet Gateway (IGW)"
  default     = false
}

// Default SSH user for OKD instance
variable "ssh_user" {
  type        = string
  description = "Default SSH user for OKD instance"
  default     = "core"
}

// Instance shape (machine type)
variable "shape_id" {
  type        = string
  description = "Instance shape (machine type)"
  default     = "VM.Standard.E5.Flex"
}

// Number of OCPUs for the instance
variable "ocpus" {
  type        = number
  description = "Number of OCPUs for the instance"
  default     = 8
}

// Amount of memory (GB) for the instance
variable "memory_in_gb" {
  type        = number
  description = "Amount of memory (GB) for the instance"
  default     = 32
}

// Size of the boot volume (GB)
variable "boot_gb" {
  type        = number
  description = "Size of the boot volume (GB)"
  default     = 900
}

// OCID of the custom image to use for the instance
variable "image_id" {
  type        = string
  description = "OCID of imported QCOW2 custom image"
  default     = "ocid1.image.oc1.XXXXXXXXXXXXXXXXX"
}

// Name of the instance
variable "instance_name" {
  type        = string
  description = "Name of the instance"
  default     = "odk01"
}

// Hostname label for the instance
variable "hostname_label" {
  type        = string
  description = "Hostname label for the instance"
  default     = "okd01"
}

// Private IP address for the node
variable "node_ip" {
  type        = string
  description = "Private IP address for the node"
  default     = "10.0.30.50"
}

// Public SSH key for instance access
variable "ssh_authorized_keys" {
  type        = string
  description = "Public SSH key for instance access"
  default     = "ssh-key"
}

// Path to the SSH private key corresponding to ssh_authorized_keys
variable "ssh_private_key" {
  type        = string
  description = "Path to SSH private key corresponding to ssh_authorized_keys"
  default     = "~/.ssh/xxxxxx"
}

// Domain name for the deployment
variable "domain" {
  type        = string
  description = "Domain name for the deployment"
  default     = "mysqllab.com"
}

// Cluster subdomain (e.g. okdk8s) for private DNS zone
variable "cluster_subdomain" {
  type        = string
  description = "Cluster subdomain (e.g. okdk8s) for private DNS zone"
  default     = "okdk8s"
}

// OCID of an existing route table (used if create_igw=false)
variable "route_table_id" {
  type        = string
  description = "OCID of an existing route table (used if create_igw=false)"
  default     = ""
}

