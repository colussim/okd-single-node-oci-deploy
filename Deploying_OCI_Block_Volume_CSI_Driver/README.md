# Deploying OCI Block Volume CSI Driver on Kubernetes / OpenShift

This guide explains how to deploy the **Oracle Cloud Infrastructure (OCI) Block Volume CSI driver** on a Kubernetes or OpenShift cluster running on OCI, using YAML manifests only 
Before deploying the **OCI Container Storage Interface (CSI) Driver**, make sure the following prerequisites are satisfied.

![deploy_oci_block_cssi.png](imgs/deploy_oci_block_cssi.png)
---

## 📝 Prerequisites

- A running Kubernetes or OpenShift cluster in **OCI**.
- The **OCI Cloud Controller Manager (CCM)** is already deployed (`oci-cloud-controller-manager`).
- The cluster nodes run in OCI and have permissions via **Instance Principals** (Dynamic Group + Policies).
- `kubectl` or `oc` configured to access your cluster.

---

## ⚙️ Create Provider Configuration

The CSI driver needs a provider configuration to talk to OCI APIs.  
Create a file called `provider-config.yaml`:

```yaml
kind: CloudProviderConfig
apiVersion: oci.cloud.oracle.com/v1alpha1
auth:
  useInstancePrincipals: true
  region: us-ashburn-1                # Replace with your region
compartmentOcid: ocid1.compartment.oc1..example12345
```

---

## 🔑 Create the Secret for the CSI Driver

The CSI driver looks for a secret named `oci-volume-provisioner` in the `kube-system` namespace.  
Create it from the provider config:

```bash
kubectl -n kube-system create secret generic oci-volume-provisioner \
  --from-file=config.yaml=provider-config.yaml
```

---

## 🚀 Deploy CSI Controller and Node Plugins

Apply the manifests for the latest release (example: **v1.33.0**):

```bash
kubectl apply -f https://github.com/oracle/oci-cloud-controller-manager/releases/download/v1.33.0/oci-csi-controller.yaml
kubectl apply -f https://github.com/oracle/oci-cloud-controller-manager/releases/download/v1.33.0/oci-csi-node.yaml
```

Verify that pods are running:

```bash
kubectl -n kube-system get pods | grep csi-oci
```

You should see:
- `csi-oci-controller-...` in **7/7 Running**
- `csi-oci-node-...` in **4/4 Running**

---

## 🗂️ Create a StorageClass

Create a StorageClass to provision OCI Block Volumes:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: oci-bv
provisioner: blockvolume.csi.oraclecloud.com
parameters:
  csi.storage.k8s.io/fstype: xfs
  vpusPerGB: "10"                   # Performance tier: 0, 10, 20, 30
  attachmentType: "paravirtualized" # or "iscsi" if required
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

Apply it:

```bash
kubectl apply -f sc-oci-bv.yaml
```

---

## 📦 Test with a PVC

Create a test PersistentVolumeClaim (PVC):

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-test
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 10Gi
  storageClassName: oci-bv
```

Apply it:

```bash
kubectl apply -f pvc-test.yaml
kubectl get pvc pvc-test -w
```

Expected: A **PersistentVolume (PV)** is dynamically created in OCI Block Volumes.

---

## ✅ Summary

1. Create a provider configuration (`provider-config.yaml`).
2. Store it in a Kubernetes secret `oci-volume-provisioner` (namespace `kube-system`).
3. Deploy CSI Controller and Node manifests.
4. Create a StorageClass using the CSI provisioner.
5. Test with a PVC to confirm block volume provisioning.

With this setup, your cluster can dynamically provision and attach OCI Block Volumes to workloads.

---

## 📚 References

- [oci-cloud-controller-manager](https://github.com/oracle/oci-cloud-controller-manager)

---
<table>
<tr style="border: 0px transparent">
	<td style="border: 0px transparent"><a href="../README.md" title="home">🏠</a></td>
</tr>
</tr>

</table>