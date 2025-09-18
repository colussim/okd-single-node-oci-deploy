# Deploying OCI Cloud Controller Manager (CCM) on Kubernetes / OpenShift

The **OCI Cloud Controller Manager (CCM)** is required to integrate Kubernetes or OpenShift clusters with [Oracle Cloud Infrastructure (OCI)](https://www.oracle.com/cloud/).  
It enables dynamic provisioning and lifecycle management of load balancers, nodes, and routes within OCI.

---

## 📝 Prerequisites

- A running Kubernetes (v1.24+) or OpenShift cluster.  
- OCI tenancy, region, and compartment access.  
- Proper IAM policies and a service account with permissions for the CCM.  
- Kubeconfig with cluster-admin privileges.  

---

## ⚙️ Create Provider Configuration

The Cloud Controller Manager (CCM) requires access to your OCI API credentials and configuration in order to authenticate with your tenancy and manage cloud resources (load balancers, routes, etc.).

You must provide a cloud-provider.yaml file containing the OCI configuration.
Create a file called `cloud-provider.yaml`:

```yaml
auth:
  useInstancePrincipals: false
  region: us-ashburn-1                # Replace with your region
  tenancy: ocid1.tenancy.oc1..aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  user: ocid1.user.oc1..aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  key: |
    -----BEGIN RSA PRIVATE KEY-----
    <snip>
    -----END RSA PRIVATE KEY-----
  fingerprint: 8c:bf:17:7b:5f:e0:7d:13:75:11:d6:39:0d:e2:84:74
compartmentOcid: ocid1.compartment.oc1..example12345 # Replace with your comportment OCID

vcn: ocid1.vcn.oc1.iad.xxxxxx  # Replace with your vcn OCID

loadBalancer:
  subnet1: ocid1.subnet.oc1.iad.aaaaxxxx # Replace with your subnet OCID
  securityListManagementMode: None
```

An example configuration file can be found [here](https://github.com/oracle/oci-cloud-controller-manager/blob/master/manifests/provider-config-example.yaml).

---

## 🔑 Create the Secret for the authentification

Once the file is ready, create the Kubernetes Secret in the kube-system namespace so that the CCM can mount it at runtime:

```bash
kubectl -n kube-system create secret generic oci-cloud-controller-manager \
  --from-file=config.yaml=cloud-provider.yaml \
  --from-file=cloud-provider.yaml=cloud-provider.yaml
```


## 🚀 Deployment

Apply the manifests for the latest release (example: **v1.33.0**):

```bash
kubectl apply -f https://github.com/oracle/oci-cloud-controller-manager/releases/download/v1.33.0/oci-cloud-controller-manager-rbac.yaml
$ kubectl apply -f https://github.com/oracle/oci-cloud-controller-manager/releases/download/v1.33.0/oci-cloud-controller-manager.yaml


```

## Troubleshooting

Issue: Pods fail to start due to imagePullSecrets

When deploying on some clusters (especially OpenShift), you may encounter an error where the CCM pod cannot pull its image due to an invalid or missing secret.

Reference: GitHub Issue [#510](https://github.com/oracle/oci-cloud-controller-manager/issues/510)

Fix:
Patch the deployment to remove the imagePullSecrets section from the default manifests.
```bash
kubectl patch deployment oci-cloud-controller-manager \
  -n kube-system \
  --type=json \
  -p='[{"op": "remove", "path": "/spec/template/spec/imagePullSecrets"}]'


```

Check the CCM logs to ensure it's running correctly:

```bash
kubectl -n kube-system get po | grep oci

oci-cloud-controller-manager-97ltt    1/1     Running   1    44s

kubectl -n kube-system logs oci-cloud-controller-manager-97ltt 


```



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