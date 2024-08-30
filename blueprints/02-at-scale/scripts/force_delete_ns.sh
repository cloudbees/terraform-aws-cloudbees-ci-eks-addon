#!/bin/bash
###############################################################################
# Remove all api-resources in namespace and then remove the namespace
#
# Query all api-resources in namespace, remove the finalizers and 
# then remove the resource. Finally remove the finalizers on the Namespace and 
# finally remove the namespace.
#
# Oracle Consulting Netherlands
#
# History
# -------
# 2024-05-11, M. van den Akker, Initial Creation 
# 
###############################################################################

#Source https://medium.com/nerd-for-tech/force-delete-kubernetes-namespace-198f0e4b109e

export NS=$1

function count_apiresources() {
  resource=$1
  ROWS=$(kubectl get "$resource" -n "$NS" -o name |wc -l);
  echo "$ROWS"
  return "$ROWS"
}

function patch_apiresources(){
  resource=$1
  for resource_name in $(kubectl get "$resource" -n "$NS" -o name); do
    echo "Patch $resource $resource_name"
    kubectl -n "$NS" patch "$resource_name" -p '{"metadata":{"finalizers":null}}' --type=merge
  done
}

function delete_apiresources(){
  resource=$1
  for resource_name in $(kubectl get "$resource" -n "$NS" -o name); do
    echo "Delete $resource $resource_name"
    kubectl -n "$NS" delete "$resource_name" --force
  done
}

function patch_delete_apiresources(){
  API_RESOURCE=$1
  ROWS=$(count_apiresources "$API_RESOURCE")
  if [ "$ROWS" -gt 0 ]; then
    echo "Patch $ROWS occurences of api-resource $API_RESOURCE for $NS to remove finalizers"
    patch_apiresources "$API_RESOURCE"
    ROWS=$(count_apiresources "$API_RESOURCE")
    if [ "$ROWS" -gt 0 ]; then
      echo Delete "$ROWS" occurences of api-resource "$API_RESOURCE" for "$NS"
      delete_apiresources "$API_RESOURCE"
    else
      echo No occurences of api-resource "$API_RESOURCE" left.
    fi
  else
    echo No occurences of api-resource "$API_RESOURCE" found...
  fi
}

for API_RESOURCE in $(kubectl api-resources --no-headers --verbs=list --namespaced -o name); do
  patch_delete_apiresources "$API_RESOURCE"
done

echo Patch namespace "$NS" to clear metadata.finalizers 
kubectl patch ns "$NS" -p '{"metadata":{"finalizers":null}}'
echo Patch namespace "$NS" to clear spec.finalizers 
kubectl patch ns "$NS" -p '{"spec":{"finalizers":null}}'
echo Patch namespace "$NS" to clear metadata.annotations
kubectl patch ns "$NS" -p '{"metadata":{"annotations":null}}'
echo Force delete namespace "$NS"
kubectl delete ns "$NS" --grace-period=0 --force