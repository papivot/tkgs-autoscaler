# TKGs Autoscaler

---
**Disclaimer**: This repository is a Bash-based modest cluster Autoscaler implementation for Tanzu Kubernetes Grid Services running on vSphere with Tanzu.  This process does not replace any official solution provided by VMware.
---

## How to execute the Autoscaler
The script `autoscaler.sh` can be executed from inside a vSphere Supervisor Cluster or run outside of the cluster. 

### Executing as a script outside the Supervisor Cluster (primarily for debugging purposes)
When running the Autoscaler bash script outside the cluster, you need to provide the configuration parameters (see autoscaling logic below) in the `autoscale.config` file. Ensure that a valid kubeconfig file exists with access to the WCP namespace containing the TKGs cluster(s).

### Executing as a deployment inside the Supervisor Cluster (standard processing)
To deploy and execute from within the Supervisor cluster, build your container image using the `Dockerfile` provided in the `scripts` folder. There is already a prebuilt image that you could leverage if creating your container image is not an option.  A sample `autoscaler-deployment.yaml` is also available in the Kubernetes folder to deploy the Autoscaler - within the WCP Namespace of the TKGs cluster(s) that need to be autoscaled. The configuration values, identical to the ones provided through the `autoscale.config`, needs to be delivered using the deployment's environment variables. 

Note: some specific `roles` and `rolebindings` are required for Autoscaler to run. To configure these, you need to deploy the `authz.yaml` file from *within the control plane node of the Supervisor cluster*. This additional requirement is due to the access limitations that have been enforced in WCP. 

---
### Autoscaling Logic 
(use this project only if the logic meets your requirements)

* SCRIPT_FREQ_MIN - determines in minutes how often the reconciliation loop is executed. Smaller values may lead to more aggressive scale-up and scale-down.
* NAMESPACE - The Supervisor Cluster namespace where the Autoscaler will run and autoscale the Workload clusters.
* EXCLUDE_CLUSTER - List of clusters you would like to exclude from the Autoscaling consideration within the namespace. 
* MAX_NODE_COUNT and MIN_NODE_COUNT - The allowed maximum and minimum worker node count that the Autoscaler will scale up or down.
* MAX_TOTAL_CPU and MAX_TOTAL_MEM - A decimal value (0 to 1) expressed as a percent. The total max allocation that is allowed across all the worker nodes during scale-in calculation. 

*Scale-up* -  If the TKG cluster **cannot schedule any pending pods due to CPU or memory pressure**, the process scales the worker node count by 1. Additonal scale-up is prevented, until the new node joins the cluster. This process is repeated until all pending pods have been successfully deployed or the cluster has reached the `MAX_NODE_COUNT`.

*Scale-down* - If there are **no pending pods** in the cluster, attempt to scale down the cluster. Check if by removing one worker node, the sum of allocated resources (CPU and/or memory)  is less than the sum off thr available resources `MAX_TOTAL_CPU` or `MAX_TOTAL_MEM`. If so, decrease the node count by one. Scale-in is repeated untill the above condition is met or the `MIN_NODE_COUNT` is reached.

### Sample Output
The outputs of the autoscaler may be similer to this - 

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
