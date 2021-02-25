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

convert_to_bytes()
{
	VALUE_IN_Gi=${1%Gi}
	if [[ ${VALUE_IN_Gi} == ${1} ]]
	then
		VALUE_IN_Mi=${1%Mi}
		if [[ ${VALUE_IN_Mi} == ${1} ]]
		then
			VALUE_IN_Ki=${1%Ki}
			if [[ ${VALUE_IN_Ki} == ${1} ]] 
			then
				echo "${1}"|bc
			else
				echo "${VALUE_IN_Ki}*1024"|bc
			fi
		else
			echo "${VALUE_IN_Mi}*1024*1024"|bc
		fi
	else
		echo "${VALUE_IN_Gi}*1024*1024*1024"|bc
	fi
}

convert_to_millicpu()
{
	VALUE_IN_m=${1%m}
	if [[ ${VALUE_IN_m} == ${1} ]]
	then
		echo "${VALUE_IN_m}*1000"|bc
	else
		echo "${VALUE_IN_m}"|bc
	fi
}

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
			NODE_MEM_SUM="0"
			NODE_CPU_SUM="0"
			NODE_ALLOCATED_MEM_SUM="0"
			NODE_ALLOCATED_CPU_SUM="0"

			# Generating Workload cluster Kubeconfig
			kubectl get secrets ${WORKLOAD_CLUSTER}-kubeconfig -n ${NAMESPACE} -o json |jq -r '.data.value'|base64 -d > ${WORKLOAD_CLUSTER}-kubeconfig

			NUM_WORKER_NODES=$(kubectl get nodes --kubeconfig=${WORKLOAD_CLUSTER}-kubeconfig --selector 'node-role.kubernetes.io/master!=' -o json |jq -r '.items'|jq length)
			for NODE in $(kubectl get nodes --selector 'node-role.kubernetes.io/master!=' -o json| jq -r '.items[].metadata.name')
			do
				echo "Info: Gathering CPU and meory allocation stats from ${NODE}"
				NODE_DETAIL=$(kubectl describe node ${NODE})
				NODE_MEMORY=`echo ${NODE_DETAIL}|grep Allocatable -A 7 | grep memory|awk '{print $2}'`
				NODE_CPU=`echo ${NODE_DETAIL} | grep Allocatable -A 7 | grep cpu | awk '{print $2}'`
				NODE_ALLOCATED_MEMORY=`echo ${NODE_DETAIL} |grep Allocated -A 7 | grep memory | awk '{print $2}'`
				NODE_ALLOCATED_CPU=`echo ${NODE_DETAIL} | grep Allocated -A 7 | grep cpu | awk '{print $2}'`
				temp1=`convert_to_bytes ${NODE_MEMORY}`
				temp2=`convert_to_bytes ${NODE_ALLOCATED_MEMORY}`
				temp3=`convert_to_millicpu ${NODE_CPU}`
				temp4=`convert_to_millicpu ${NODE_ALLOCATED_CPU}`
								
				NODE_MEM_SUM+="+${temp1}"
				NODE_ALLOCATED_MEM_SUM+="+${temp2}"
				NODE_CPU_SUM+="+${temp3}"
				NODE_ALLOCATED_CPU_SUM+="+${temp4}"
			done
			
			# Code for Scale in check goes here
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
			if [ ${SCALE_OUT_REQ} -eq 1 ]
			then
				scale_out ${WORKLOAD_CLUSTER} ${NAMESPACE} ${MAX_NODE_COUNT}
				break
			fi
		
			# Code for Scale in check goes here
			if [[ $NUM_WORKER_NODES -gt 1 ]]
			then
				ALLOC_CPU=`echo ${NODE_ALLOCATED_CPU_SUM} | bc`
				ALLOC_MEM=`echo ${NODE_ALLOCATED_MEM_SUM} | bc`
				TARGET_CPU=`echo "scale=0; (${NODE_CPU_SUM})*${MAX_TOTAL_CPU}*(${NUM_WORKER_NODES}-1)/${NUM_WORKER_NODES}" |bc`
				TARGET_MEM=`echo "scale=0; (${NODE_MEM_SUM})*${MAX_TOTAL_MEM}*(${NUM_WORKER_NODES}-1)/${NUM_WORKER_NODES}" |bc`
				if [[ ${ALLOC_CPU} -lt ${TARGET_CPU} ]] && [[ ${ALLOC_MEM} -lt ${TARGET_MEM} ]]
   				then
					SCALE_IN_REQ=1
				fi
			fi
			if [ ${SCALE_IN_REQ} -eq 1 ]
			then
	 			scale_in ${WORKLOAD_CLUSTER} ${NAMESPACE} ${MIN_NODE_COUNT}
				break
			fi
		fi
	done
	echo "Info: Script sleeping for ${SCRIPT_FREQ_MIN} minutes..."
	sleep ${SCRIPT_FREQ_MIN}m
done
