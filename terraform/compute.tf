
data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.tenancy_ocid
}

locals {
  installation_disk = var.installation_disk
  allow_wipe_flag   = var.allow_wipe ? "true" : "false"
  bootstrap_par_url = "https://objectstorage.${var.region}.oraclecloud.com${oci_objectstorage_preauthrequest.bootstrap_par.access_uri}"

  scos_base_url = "https://rhcos.mirror.openshift.com/art/storage/prod/streams/${var.scos_stream}/builds/${var.scos_build}/${var.scos_arch}"

  scos_kernel_url  = "${local.scos_base_url}/scos-${var.scos_build}-live-kernel.${var.scos_arch}"
  scos_initrd_url  = "${local.scos_base_url}/scos-${var.scos_build}-live-initramfs.${var.scos_arch}.img"
  scos_rootfs_url  = "${local.scos_base_url}/scos-${var.scos_build}-live-rootfs.${var.scos_arch}.img"
}

resource "oci_objectstorage_preauthrequest" "bootstrap_par" {
  bucket       = var.okd_bucket_name
  namespace    = data.oci_objectstorage_namespace.ns.namespace
  name         = "sno-bootstrap-par"
  access_type  = "ObjectRead"
  object_name       = var.okd_ignition_object
  time_expires = timeadd(timestamp(), "168h")
}

############################################
# NSG for SNO
############################################
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

resource "null_resource" "start_clock" {
  triggers = { started_at = timestamp() }
}

################################################
# Instance OKD SNO – boot sur image custom SCOS
################################################
resource "oci_core_instance" "odk_instance" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  shape               = var.shape

  source_details {
    source_type             = "image"
    source_id               = var.base_linux_image_ocid   
    boot_volume_size_in_gbs = var.boot_gb
    
  }

  dynamic "shape_config" {
    for_each = [1]
    content {
      memory_in_gbs = var.memory_gbs
      ocpus         = var.ocpus
    }
  }

  display_name = var.instance_name

  create_vnic_details {
    subnet_id        = local.sno_subnet_id
    nsg_ids          = concat([oci_core_network_security_group.sno_nsg.id], var.nsg_ids)
    hostname_label   = var.hostname_label
    private_ip       = var.node_ip
    assign_public_ip = true
  }

  metadata = {
    ssh_authorized_keys = var.ssh_authorized_keys
  user_data = base64encode(<<-CLOUDINIT
    #!/bin/bash
    set -euxo pipefail

    CLUSTER_FQDN="${var.cluster_subdomain}.${var.domain}"
    NODE_IP="$(ip -o -4 addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -n1)"
    MTU_TARGET="1500"

    # 1) Wait for outgoing network (HTTP)
    echo "== [1] Test egress HTTP(S) =="
    for i in {1..60}; do curl -fsS https://oracle.com >/dev/null && break || sleep 2; done

    # 2) NTP sync
    echo "== [2] NTP sync =="
    systemctl enable --now chronyd || true
    timedatectl set-ntp true || true
    for i in {1..30}; do
      if chronyc tracking 2>/dev/null | grep -qiE 'Leap status\s*:\s*Normal|State\s*:\s*.*synchron'; then
         echo "[preflight] NTP synced"
       break
      fi
     sleep 3
    done

    echo "== [3] NetWork Config =="
    # MTU safe (évite les pulls lents/fragiles)
    IFACE="$(ip route | awk '/default/ {print $5; exit}')"
    [ -n "$${IFACE:-}" ] && nmcli con modify "$${IFACE}" 802-3-ethernet.mtu "$${MTU_TARGET}" 2>/dev/null || true

    if ! grep -q '8.8.8.8' /etc/resolv.conf; then
        printf 'nameserver 8.8.8.8\n' >> /etc/resolv.conf || true
    fi

    NO_PROXY_LIST="127.0.0.1,::1,localhost,$${NODE_IP},10.0.0.0/8,10.128.0.0/14,172.30.0.0/16,.cluster.local,api.$${CLUSTER_FQDN},api-int.$${CLUSTER_FQDN}"
    mkdir -p /etc/systemd/system/{crio.service.d,kubelet.service.d}
    cat >/etc/systemd/system/crio.service.d/10-proxy.conf <<EOF
    [Service]
    Environment="NO_PROXY=$${NO_PROXY_LIST}"
    EOF
    cat >/etc/systemd/system/kubelet.service.d/10-proxy.conf <<EOF
    [Service]
    Environment="NO_PROXY=$${NO_PROXY_LIST}"
    EOF
    systemctl daemon-reload

    HOSTS_LINE="$${NODE_IP} api.$${CLUSTER_FQDN} api-int.$${CLUSTER_FQDN} console-openshift-console.apps.$${CLUSTER_FQDN} oauth-openshift.apps.$${CLUSTER_FQDN}"
    grep -q "api.$${CLUSTER_FQDN}" /etc/hosts || echo "$${HOSTS_LINE}" >> /etc/hosts

  
    # ---------- Kubelet nodeIP force ----------
    mkdir -p /etc/systemd/system/kubelet.service.d
    cat >/etc/systemd/system/kubelet.service.d/20-nodeip.conf <<EOF
    [Service]
    Environment="KUBELET_NODE_IP=$${NODE_IP}"
    EOF
    systemctl daemon-reload


    # 4) Required tools
    echo "== [4] Required tools =="
    (dnf -y install curl kexec-tools jq || yum -y install curl kexec-tools jq)

    # 5) Artefacts SCOS

    SCOS_BASE_URL="${local.scos_base_url}"
    KERNEL_URL="${local.scos_kernel_url}"
    INITRD_URL="${local.scos_initrd_url}"
    ROOTFS_URL="${local.scos_rootfs_url}"
    IGN_URL="${local.bootstrap_par_url}"
    

    # 6) Pre-checks

    echo "== [6] Check Ignition v3 =="
    curl -fsI "$${ROOTFS_URL}" >/dev/null

    IGN_VER="$( { curl -fsSL --compressed "$${IGN_URL}" || curl -fsSL "$${IGN_URL}" | zcat; } 2>/dev/null | jq -r '.ignition.version' || true )"
    echo "IGNITION_VERSION=$IGN_VER"
    echo "$IGN_VER" | grep -Eq '^[3-9]\.' || { echo "Ignition not v3.x or inaccessible: $${IGN_URL}"; exit 1; }

    # 7) Cleaning the target disk
    
    echo "== [7] Cleaning the target disk =="
    TARGET_DISK="${local.installation_disk}"
    ALLOW_WIPE="${local.allow_wipe_flag}"

    if [ "$ALLOW_WIPE" = "true" ]; then
    echo "[DISK PREP] Cible: $TARGET_DISK"

    swapoff -a || true

    # Stop LVM monitor (if present) and deactivate  VGs/LVs
    systemctl disable --now lvm2-monitor 2>/dev/null || true

    # Disable all LVs/VGs that affect the target disk
    for vg in $(vgs --noheadings -o vg_name 2>/dev/null | awk '{$1=$1};1'); do
      lvchange -an "$vg" 2>/dev/null || true
      vgchange -an "$vg" 2>/dev/null || true
    done

    # Detach the device mappers that point to the disk
    for dm in $(lsblk -nrpo NAME,TYPE "$TARGET_DISK" 2>/dev/null | awk '$2=="crypt"||$2=="lvm"{print $1}'); do
      dmsetup remove --retry "$dm" 2>/dev/null || true
    done

    # Attempt to dismantle everything that has been assembled from the disk
    while read -r dev mp; do
      umount -f "$mp" 2>/dev/null || true
    done < <(lsblk -nrpo NAME,MOUNTPOINT "$TARGET_DISK" | awk 'NF==2')

    # Purge partition/fs signatures
    wipefs -fa "$TARGET_DISK" 2>/dev/null || true
    sgdisk --zap-all "$TARGET_DISK" 2>/dev/null || true
    dd if=/dev/zero of="$TARGET_DISK" bs=1M count=10 oflag=direct,dsync 2>/dev/null || true
    blockdev --rereadpt "$TARGET_DISK" 2>/dev/null || true
    partprobe "$TARGET_DISK" 2>/dev/null || true

    echo "[DISK PREP] Finish"
    else
    echo "[DISK PREP] Skip (ALLOW_WIPE=false)"
    fi


    # 8) Download kernel/initramfs
    echo "== [8] Download kernel/initramfs =="
    mkdir -p /opt/scos
    curl -fSL "$${KERNEL_URL}" -o /opt/scos/vmlinuz
    curl -fSL "$${INITRD_URL}" -o /opt/scos/initramfs.img

    # 8) Switch to SCOS live
    echo "== [8] Kexec switch to SCOS Live =="
    KARGS="rd.neednet=1 ip=dhcp \
           ignition.platform.id=metal ignition.firstboot \
           ignition.config.url=$${IGN_URL} \
           coreos.live.rootfs_url=$${ROOTFS_URL} \
           console=ttyS0,115200n8 console=tty0"

    rm -f /opt/openshift/.bootkube.done || true
    rm -rf /etc/kubernetes/manifests/* || true
    kexec -l /opt/scos/vmlinuz --initrd=/opt/scos/initramfs.img --append="$${KARGS}"
    systemctl kexec
  CLOUDINIT
  )
}

  launch_options {
   boot_volume_type = "PARAVIRTUALIZED"
   network_type     = "PARAVIRTUALIZED"

  }

  preserve_boot_volume = false
}

# Primary VNIC -> IP publique
data "oci_core_vnic_attachments" "va" {
  compartment_id      = var.compartment_ocid
  availability_domain = oci_core_instance.odk_instance.availability_domain
  instance_id         = oci_core_instance.odk_instance.id
}

data "oci_core_vnic" "primary" {
  vnic_id = data.oci_core_vnic_attachments.va.vnic_attachments[0].vnic_id
}


##################################################
# Waiting for SCOS to become available
##################################################

resource "local_file" "hosts_override" {
  content = "${data.oci_core_vnic.primary.public_ip_address} api.${var.cluster_subdomain}.${var.domain} api-int.${var.cluster_subdomain}.${var.domain} console-openshift-console.apps.${var.cluster_subdomain}.${var.domain} oauth-openshift.apps.${var.cluster_subdomain}.${var.domain}"
  filename = "${path.module}/hosts.override"
}

resource "null_resource" "wait_console" {
   triggers = {
   
    ip           = data.oci_core_vnic.primary.public_ip_address
    cluster_fqdn = "${var.cluster_subdomain}.${var.domain}"
  }
  
 provisioner "local-exec" {
    interpreter = ["/bin/bash","-c"]
    command = <<-EOT
     
      set -o pipefail

      IP="${data.oci_core_vnic.primary.public_ip_address}"
      CONSOLE_HOST="console-openshift-console.apps.${var.cluster_subdomain}.${var.domain}"
      URL="https://"$CONSOLE_HOST

      echo "⌛ Waiting for the console: "$URL" (via "$IP")"
      start_ts=$(date +%s)
      attempt=0

      while true; do
        attempt=$((attempt+1))
       
        code=$(curl -skI --resolve "$CONSOLE_HOST:443:$IP" --max-time 8 "$URL/" \
               | awk 'NR==1{print $2}' 2>/dev/null)

        if [ "$code" = "200" ] || [ "$code" = "301" ] || [ "$code" = "302" ]; then
          elapsed=$(( $(date +%s) - start_ts ))
          echo "✅ Console READY (HTTP "$code") after "$elapsed"s (attempt #"$attempt")"
          exit 0
        fi

        elapsed=$(( $(date +%s) - start_ts ))
        echo "⌛ console not ready (attempt #"$attempt", http='"$code"', elapsed="$elapsed"s)"
        sleep 10
      done
    EOT
  }

  depends_on = [oci_core_instance.odk_instance]
}

resource "null_resource" "end_clock" {
  triggers = { finished_at = timestamp() }

  depends_on = [
    null_resource.wait_console,
   
  ]
}