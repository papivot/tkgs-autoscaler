# TKGs Autoscaler

This repository is a Bash based modest cluster autoscaler implementation for TKGs - vSphere 7 with Tanzu. Currently, only scale-out is implemented, and scale-in is being implemented. 

The script `autoscaler.sh` can be executed from inside a vSphere 7 Supervisor Kubernetes cluster or be run outside of the cluster. 

When running the autoscaler outside the cluster, provide the configuration parameters in the `autoscale.config` file. Make sure that a valid kubeconfig file exists with access to the WCP namespace that contains the TKGs cluster(s).

To deploy and execute from within the Supervisor cluster, build your container image using the Docker file provided in the scripts folder. There is already a prebuilt image that you could leverage that if creating your container image is not an option. 





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
