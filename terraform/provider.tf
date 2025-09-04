terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.20.0"
    }
  }
}


provider "oci" {
  tenancy_ocid     = "ocid1.tenancy.oc1..XXXXXXXXX"
  user_ocid        = "ocid1.user.oc1..XXXXXXXXXX"
  private_key_path = "XXXXXXXXXXXX.pem"
  fingerprint      = "XXXXXXXXXXXX"
  region           = "us-ashburn-1"
}
