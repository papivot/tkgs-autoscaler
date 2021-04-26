# TKGs Autoscaler

Disclaimer: This repository is a Bash-based modest cluster Autoscaler implementation for Tanzu Kubernetes Grid Services running on vSphere with Tanzu.  This does not replace any official solution provided by VMware.

## How to execute the Autoscaler
The script `autoscaler.sh` can be executed from inside a vSphere Supervisor Cluster or run outside of the cluster. 

### Executing as a script from outside the Supervisor Cluster (primarily for debugging purposes)
When running the Autoscaler bash script outside the cluster, provide the configuration parameters in the `autoscale.config` file. Ensure that a valid kubeconfig file exists with access to the WCP namespace containing the TKGs cluster(s).

### Executing as a script from inside the Supervisor Cluster (normal processing)
To deploy and execute from within the Supervisor cluster, build your container image using the `Dockerfile` provided in the `scripts` folder. There is already a prebuilt image that you could leverage if creating your container image is not an option.  A sample `deployment.yaml` is also available in the Kubernetes folder to deploy the Autoscaler within the WCP Namespace of the TKGs cluster(s) that need to be autoscaled. The configuration values, identical to the ones provided through the `autoscale.config`, can be provided using the deployment's environment variables. 

Note: some specific `roles` and `rolebindings` are required for Autoscaler to run. To configure these, you need to deploy the `authz.yaml` file from within the control plane node of the Supervisor cluster. This additional requirement is due to the access limitations that have been enforced in WCP. 


The outputs of the autoscaler is similer to this - 


```
Info: Script sleeping for 1 minutes...
Info: Cluster workload-vsphere-tkg1 failed to schedule POD(s) due to CPU pressure. Scaling required.
Info: TKC_NODE_COUNT - 1, NODES_READY - 1, VMS_READY - 1
Info: Cluster workload-vsphere-tkg1 is being scaled up to 2 nodes...
tanzukubernetescluster.run.tanzu.vmware.com/workload-vsphere-tkg1 patched
Info: Script sleeping for 1 minutes...
Info: Cluster workload-vsphere-tkg1 failed to schedule POD(s) due to CPU pressure. Scaling required.
Info: TKC_NODE_COUNT - 2, NODES_READY - 1, VMS_READY - 1
...
Info: Cluster workload-vsphere-tkg1 failed to schedule POD(s) due to CPU pressure. Scaling required.
Info: TKC_NODE_COUNT - 2, NODES_READY - 1, VMS_READY - 2
Warning: Cluster workload-vsphere-tkg1 has a node in pending create/delete state. Possible resize in progress. Skipping resize...
Info: Script sleeping for 1 minutes...
Info: Cluster workload-vsphere-tkg1 failed to schedule POD(s) due to CPU pressure. Scaling required.
...
...
Info: Cluster workload-vsphere-tkg1 failed to schedule POD(s) due to CPU pressure. Scaling required.
Info: TKC_NODE_COUNT - 2, NODES_READY - 2, VMS_READY - 2
Info: Cluster workload-vsphere-tkg1 is being scaled up to 3 nodes...
tanzukubernetescluster.run.tanzu.vmware.com/workload-vsphere-tkg1 patched
Info: Script sleeping for 1 minutes...
```
