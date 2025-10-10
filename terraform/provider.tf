terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 7.20.0"
    }
  }
}


provider "oci" {
  tenancy_ocid     = "ocid1.tenancy.oc1..xxxxx"
  user_ocid        = "ocid1.user.oc1..xxxxx"
  private_key_path = "HOME_USER/.oci/key.pem"
  fingerprint      = "xxxxx"
  region           = "us-ashburn-1"
}
