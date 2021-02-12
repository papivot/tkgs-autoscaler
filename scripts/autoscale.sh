#!/bin/bash

if [[ $INCLUSTER_CONFIG -eq 1 ]]
then
	echo "Info: Starting script within a Kubernetes cluster"
else
	if [[ -f autoscale.config ]]
	then
		echo "Info: Starting script outside a Kubernetes Cluster. Make sure a valid kubeconfig file exists for a Supervisor Cluster"
		source autoscale.config
	else
		exit 1
	fi
fi

scale_out()
{
	CLUSTER_STATUS=$(kubectl get tkc $1 -n $2 -o json|jq -r '.status.phase')
	NODE_STATUS=$(kubectl get tkc $1 -n $2 -o json|jq -r '.status.nodeStatus'|grep $1-workers)
	VM_STATUS=$(kubectl get tkc $1 -n $2 -o json|jq -r '.status.vmStatus'|grep $1-workers)
	
	TKC_NODE_COUNT=$(kubectl get tkc $1 -n $2 -o json|jq -r '.spec.topology.workers.count')
	NODE_READY_COUNT=`echo ${NODE_STATUS}|grep -o "ready"|wc -l`
	VM_READY_COUNT=`echo ${VM_STATUS}|grep -o "ready"|wc -l`
	echo "Info: TKC_NODE_COUNT - ${TKC_NODE_COUNT}, NODES_READY - ${NODE_READY_COUNT}, VMS_READY - ${VM_READY_COUNT}"

	if [ ${CLUSTER_STATUS} == "running" ]
	then
		if [ "$NODE_READY_COUNT" = "$VM_READY_COUNT" ] && [ "$VM_READY_COUNT" = "$TKC_NODE_COUNT" ]
		then
			TKC_NEW_NODE_COUNT=`echo "${TKC_NODE_COUNT}+1"|bc`
			if [ ${TKC_NEW_NODE_COUNT} -gt $3 ]
			then
				echo "Warning: Cluster ${1} already has maximum node count. Cannot scale out further..."
			else
				echo "Info: Cluster ${1} is being scaled up to ${TKC_NEW_NODE_COUNT} nodes..."
				kubectl patch tkc $1 -n $2 --type=merge -p "{\"spec\": {\"topology\": {\"workers\": {\"count\": $TKC_NEW_NODE_COUNT}}}}"
			fi
		else
			echo "Warning: Cluster ${1} has a node in pending create/delete state. Possible resize in progress. Skipping resize..."
		fi
	else
		echo "Warning: Cluster ${1} is not in Running state. Skipping resize..."
	fi
}

scale_in()
{
	CLUSTER_STATUS=$(kubectl get tkc $1 -n $2 -o json|jq -r '.status.phase')
	NODE_STATUS=$(kubectl get tkc $1 -n $2 -o json|jq -r '.status.nodeStatus'|grep $1-workers)
	VM_STATUS=$(kubectl get tkc $1 -n $2 -o json|jq -r '.status.vmStatus'|grep $1-workers)
	
	TKC_NODE_COUNT=$(kubectl get tkc $1 -n $2 -o json|jq -r '.spec.topology.workers.count')
	NODE_READY_COUNT=$(echo ${NODE_STATUS}|grep -o "ready"|wc -l)
	VM_READY_COUNT=$(echo ${VM_STATUS}|grep -o "ready"|wc -l)
	echo "Info: TKC_NODE_COUNT - ${TKC_NODE_COUNT}, NODES_READY - ${NODE_READY_COUNT}, VMS_READY - ${VM_READY_COUNT}"

	if [ ${CLUSTER_STATUS} == "running" ]
	then
		if [ "$NODE_READY_COUNT" = "$VM_READY_COUNT" ] && [ "$VM_READY_COUNT" = "$TKC_NODE_COUNT" ]
		then 
			TKC_NEW_NODE_COUNT=`echo "${TKC_NODE_COUNT}-1"|bc`
			if [ ${TKC_NEW_NODE_COUNT} -lt $3 ]
			then
				echo "Warning: $1 already has minimum node count. Cannot scale in further..."
			else
				echo "Info: Cluster ${1} is being scaled down to ${TKC_NEW_NODE_COUNT} nodes..."
				kubectl patch tkc $1 -n $2 --type=merge -p "{\"spec\": {\"topology\": {\"workers\": {\"count\": $TKC_NEW_NODE_COUNT}}}}"
			fi
		else
			echo "Warning: Cluster ${1} has a node in pending create/delete state. Possible resize in progress. Skipping resize..."
		fi
	else
		echo "Warning: Cluster ${1} is not in Running state. Skipping resize..."
	fi
}

while true
do 
	WORKLOAD_CLUSTERS=$(kubectl get tkc -n ${NAMESPACE} -o json| jq -r '.items[].metadata.name')
	for WORKLOAD_CLUSTER in ${WORKLOAD_CLUSTERS}
	do
		if [[ ! ${EXCLUDE_CLUSTERS[@]} =~ ${WORKLOAD_CLUSTER} ]]
		then	
			SCALE_OUT_REQ=0
			SCALE_IN_REQ=0

			# Generating Workload cluster Kubeconfig
			kubectl get secrets ${WORKLOAD_CLUSTER}-kubeconfig -n ${NAMESPACE} -o json |jq -r '.data.value'|base64 -d > ${WORKLOAD_CLUSTER}-kubeconfig
			
			# Check if any pending pods in the cluster.	
			PENDING_PODS_NS=$(kubectl get pods -A --kubeconfig=${WORKLOAD_CLUSTER}-kubeconfig --field-selector=status.phase==Pending -o json |jq -r '.items[] | .metadata.namespace + ";" + .metadata.name')
			for ARRAY in ${PENDING_PODS_NS}
			do
				PENDING_POD_NS=(${ARRAY//;/ })
				# Check if the Pending POD is Unschedulable due to Insufficient memory of CPU.
				UNSCHEDULABLE_MSG=$(kubectl get pods ${PENDING_POD_NS[1]} -n ${PENDING_POD_NS[0]} --kubeconfig=${WORKLOAD_CLUSTER}-kubeconfig -o json | jq -r '.status.conditions[]|select (.reason == "Unschedulable")|.message')
				if grep -qi "Insufficient cpu" <<< ${UNSCHEDULABLE_MSG}
				then
  					echo "Info: Cluster ${WORKLOAD_CLUSTER} failed to schedule POD(s) due to CPU pressure. Scaling required."
					SCALE_OUT_REQ=1
					break
				elif grep -qi "Insufficient memory" <<< ${UNSCHEDULABLE_MSG}
				then
					echo "Info: Cluster ${WORKLOAD_CLUSTER} failed to schedule POD(s) due to Memory pressure. Scaling required."
					SCALE_OUT_REQ=1
					break
				fi
			done
			# NUM_WORKER_NODES=$(kubectl get nodes --kubeconfig=${WORKLOAD_CLUSTER}-kubeconfig --selector 'node-role.kubernetes.io/master!=' -o json |jq -r '.items'|jq length)			 
			if [ ${SCALE_OUT_REQ} -eq 1 ]
			then
				scale_out ${WORKLOAD_CLUSTER} ${NAMESPACE} ${MAX_NODE_COUNT}
			fi
		
			# Code for Scale in check goes here
			### WIP
			if [ ${SCALE_IN_REQ} -eq 1 ]
			then
	 			scale_in ${WORKLOAD_CLUSTER} ${NAMESPACE} ${MIN_NODE_COUNT}
			fi
		fi
	done
	echo "Info: Script sleeping for ${SCRIPT_FREQ_MIN} minutes..."
	sleep ${SCRIPT_FREQ_MIN}m
done
