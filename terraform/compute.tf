
// Create a Network Security Group for the SNO (Single Node OpenShift) instance
resource "oci_core_network_security_group" "sno_nsg" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_ocid
  display_name   = "sno-nsg"
}


// Allow SSH (port 22) access from admin CIDR
resource "oci_core_network_security_group_security_rule" "ing_ssh" {
  network_security_group_id = oci_core_network_security_group.sno_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  description               = "SSH 22"
  source                    = var.admin_cidr

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

// Allow OpenShift API access (port 6443) from anywhere
resource "oci_core_network_security_group_security_rule" "ing_api" {
  network_security_group_id = oci_core_network_security_group.sno_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "OpenShift API 6443"
  source                    = "0.0.0.0/0"

  tcp_options {
    destination_port_range {
      min = 6443
      max = 6443
    }
  }
}

// Allow Ignition/Machine Config Operator (MCO) access (port 22623) from anywhere
resource "oci_core_network_security_group_security_rule" "ing_ignition" {
  network_security_group_id = oci_core_network_security_group.sno_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "Ignition/MCO 22623"
  source                    = "0.0.0.0/0"

  tcp_options {
    destination_port_range {
      min = 22623
      max = 22623
    }
  }
}

// Allow HTTP/HTTPS access (ports 80-443) from anywhere
resource "oci_core_network_security_group_security_rule" "ing_web" {
  network_security_group_id = oci_core_network_security_group.sno_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "HTTP/HTTPS 80/443"
  source                    = "0.0.0.0/0"

  tcp_options {
    destination_port_range {
      min = 80
      max = 443
    }
  }
}

// Allow Kubernetes NodePorts (ports 30000-32767) from anywhere (optional)
resource "oci_core_network_security_group_security_rule" "ing_nodeports" {
  network_security_group_id = oci_core_network_security_group.sno_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "K8s NodePorts 30000-32767 (optional)"
  source                    = "0.0.0.0/0"

  tcp_options {
    destination_port_range {
      min = 30000
      max = 32767
    }
  }
}

// Allow kubelet access (port 10250) from admin CIDR (optional/diagnostic)
resource "oci_core_network_security_group_security_rule" "ing_kubelet" {
  network_security_group_id = oci_core_network_security_group.sno_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "kubelet 10250 (optional)"
  source                    = var.admin_cidr

  tcp_options {
    destination_port_range {
      min = 10250
      max = 10250
    }
  }
}

// Allow all outbound traffic (egress)
resource "oci_core_network_security_group_security_rule" "eg_all" {
  network_security_group_id = oci_core_network_security_group.sno_nsg.id
  direction                 = "EGRESS"
  protocol                  = "all"
  description               = "Allow all egress"
  destination               = "0.0.0.0/0"
}

############################################
# Instance SNO
############################################
resource "oci_core_instance" "odk_instance" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  shape               = var.shape_id

  source_details {
    source_type             = "image"
    source_id               = var.image_id
    boot_volume_size_in_gbs = var.boot_gb
  }

  dynamic "shape_config" {
    for_each = [1]
    content {
      memory_in_gbs = var.memory_in_gb
      ocpus         = var.ocpus
    }
  }

  display_name = var.instance_name

  create_vnic_details {
    subnet_id        = oci_core_subnet.sno_subnet.id
    nsg_ids          = [oci_core_network_security_group.sno_nsg.id]
    hostname_label   = var.hostname_label
    private_ip       = var.node_ip
    assign_public_ip = true
  }

  metadata = {}

  launch_options {
    boot_volume_type = "PARAVIRTUALIZED"
    network_type     = "PARAVIRTUALIZED"
  }

  preserve_boot_volume = false
}

// Pull kubeconfig from the VM and merge it locally
resource "null_resource" "pull_kubeconfig_and_merge" {
  triggers = {
    instance_id = oci_core_instance.odk_instance.id
    public_ip   = data.oci_core_vnic.primary.public_ip_address
    ssh_user    = var.ssh_user
  }


  provisioner "remote-exec" {
    inline = [
      "set -euo pipefail",
      "test -f /home/${var.ssh_user}/.kube/config || (echo 'kubeconfig absent' && exit 1)",
    ]

    connection {
      host        = data.oci_core_vnic.primary.public_ip_address
      user        = var.ssh_user
      private_key = file(var.ssh_private_key)
      agent       = false
      timeout     = "5m"
    }
  }

  // Downloads kubeconfig and merges it with local config
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-euo", "pipefail", "-c"]
    command = <<-EOT
      IP="${data.oci_core_vnic.primary.public_ip_address}"
      USER="${var.ssh_user}"
      REMOTE_KCFG="/home/${var.ssh_user}/.kube/config"
      LOCAL_DIR="$${HOME}/.kube"
      LOCAL_KCFG="$${LOCAL_DIR}/okd01-kubeconfig"

      mkdir -p "$${LOCAL_DIR}"

      echo "⏳ Wait SSH on $${IP}:22 ..."
      for i in {1..60}; do
        if nc -z $${IP} 22 >/dev/null 2>&1; then break; fi
        sleep 2
      done

      echo "⬇️  SCP $${USER}@$${IP}:$${REMOTE_KCFG} -> $${LOCAL_KCFG}"
      scp -o StrictHostKeyChecking=no -i ${var.ssh_private_key} "$${USER}@$${IP}:$${REMOTE_KCFG}" "$${LOCAL_KCFG}"

      # Rename context
      SRC_CTX="$(kubectl --kubeconfig "$${LOCAL_KCFG}" config current-context)"
      kubectl --kubeconfig "$${LOCAL_KCFG}" config rename-context "$${SRC_CTX}" okd01
       

      # Merge with ~/.kube/config keeping okd01 as in the imported file
      if [ ! -f "$${LOCAL_DIR}/config" ]; then
        cp "$${LOCAL_KCFG}" "$${LOCAL_DIR}/config"
      else
       
        KUBECONFIG="$${LOCAL_DIR}/config:$${LOCAL_KCFG}" 
        kubectl config view --flatten > "$${LOCAL_DIR}/config.merged"
        mv "$${LOCAL_DIR}/config.merged" "$${LOCAL_DIR}/config"
      fi  
    
      kubectl config use-context okd01

      echo "✅ Context 'okd01' ready in $${LOCAL_DIR}/config"
    EOT
  }

  depends_on = [oci_core_instance.odk_instance]
}