# TKGs Autoscaler

This repository is a Bash based modest cluster autoscaler implementation for TKGs - vSphere 7 with Tanzu. Currently, only scale-out is implemented, and scale-in is being implemented. 

The script `autoscaler.sh` can be executed from inside a vSPhere 7 Supervisor Kubernetes cluster or be run outside of the cluster. 

When running the autoscaler bash script outside the cluster, provide the configuration parameters in the `autoscale.config` file. Ensure that a valid kubeconfig file exists with access to the WCP namespace containing the TKGs cluster(s).

To deploy and execute from within the Supervisor cluster, build your container image using the Docker file provided in the scripts folder. There is already a prebuilt image that you could leverage if creating your container image is not an option.  A sample `deployment.yaml` is also available in the kubernetes folder to deploy the autoscaler within the namespace of the TKGs cluster(s) that need to be autoscaled. The configuration values, identical to the ones provided through the autoscale, can be provided using the deployment's environment variables. 

Note: there are some specific `roles` and `rolebindings` that are required for autoscaler to run. To configure these, you need to deploy the `authz.yaml` file from within the control plane node of the Supervisor cluster. This additional requirement is due to the access limitations that have been enforced in WCP. 

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
