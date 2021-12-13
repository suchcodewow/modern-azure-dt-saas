#!/bin/bash

source "./lib/_locations.lib"

#*********************************
if [ -f "$CREDS_FILE" ]
then
    DT_BASEURL=$(cat $CREDS_FILE | jq -r '.DT_BASEURL')
    DT_API_TOKEN=$(cat $CREDS_FILE | jq -r '.DT_API_TOKEN')
    DT_PAAS_TOKEN=$(cat $CREDS_FILE | jq -r '.DT_PAAS_TOKEN')
    DT_ENVIRONMENT_ID=$(cat $CREDS_FILE | jq -r '.DT_ENVIRONMENT_ID')
    AZURE_RESOURCE_GROUP=$(cat $CREDS_FILE | jq -r '.AZURE_RESOURCE_GROUP')
    AZURE_SUBSCRIPTION=$(cat $CREDS_FILE | jq -r '.AZURE_SUBSCRIPTION')
    AZURE_LOCATION=$(cat $CREDS_FILE | jq -r '.AZURE_LOCATION')
    RESOURCE_PREFIX=$(cat $CREDS_FILE | jq -r '.RESOURCE_PREFIX')
    AZURE_AKS_CLUSTER_NAME=$(cat $CREDS_FILE | jq -r '.AZURE_AKS_CLUSTER_NAME')

else
  echo "ABORT: CREDS_FILE: $CREDS_FILE not found"
  exit 1
fi

AZURE_SP_NAME="$AZURE_RESOURCE_GROUP-sp"

echo ""
echo "Dynatrace token: $DT_API_TOKEN"
echo "Azure Subscription ID: $AZURE_SUBSCRIPTION"
echo "Azure Subscription Name: $(az account show --query name --output tsv)"
echo ""

#Display Resource Group status
ARP_status=$(az group list --query "[?name=='$AZURE_RESOURCE_GROUP'].name" --output tsv)
if [ -z "$ARP_status" ]; then
  echo "!! $AZURE_RESOURCE_GROUP not detected"
else
  echo "Azure Resource Group: $AZURE_RESOURCE_GROUP"
fi

#Display Active Gate status
AG_status=$(az vm list-ip-addresses -g $AZURE_RESOURCE_GROUP -n dt-orders-active-gate --query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" | jq -r .[])
  if [ -z "$AG_status" ]; then
    echo "!! dt-orders-active-gate not detected"
  else
   #no error so running
    echo "dt-orders-active-gate login: azureuser@$AG_status pw: Azureuser123#"
  fi

#Display Monolith status
ML_HOSTNAME="dt-orders-monolith"
ML_status=$(az vm list-ip-addresses -g $AZURE_RESOURCE_GROUP -n $ML_HOSTNAME --query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" | jq -r .[])
  if [ -z "$ML_status" ]; then
    echo "!! $ML_HOSTNAME not detected"
  else
   #no error so running
    echo "$ML_HOSTNAME login: workshop@$ML_status pw: Workshop123#"
<<<<<<< HEAD
    echo "$ML_HOSTNAME URL: http://$ML_status"
=======
>>>>>>> 9e7241cb2f4bfda3da35af05e36f268855b8a442
  fi

#Display AKS Kubernetes Cluster status
AKS_status=$(AKSCHECK=$(az aks show -n $AZURE_AKS_CLUSTER_NAME --resource-group $AZURE_RESOURCE_GROUP --query id 2>&1 | grep "NotFound"))
  if [ -z "$ML_status" ]; then
    echo "!! AKS $AZURE_AKS_CLUSTER_NAME not detected"
  else
   #no error so running
    echo "AKS $AZURE_AKS_CLUSTER_NAME"
<<<<<<< HEAD
    az aks get-credentials --resource-group $AZURE_RESOURCE_GROUP --name $AZURE_AKS_CLUSTER_NAME
=======
>>>>>>> 9e7241cb2f4bfda3da35af05e36f268855b8a442
  fi

if [ -f "$SP_FILE" ]
then
  SP_appID=$(cat $SP_FILE | jq -r '.appId')
  SP_password=$(cat $SP_FILE | jq -r '.password')
  SP_tenant=$(cat $SP_FILE | jq -r '.tenant')

  echo ""
  echo "Client ID (appID): $SP_appID"
  echo "Tenant ID: $SP_tenant"
  echo "Password: $SP_password"
else
  echo "Service Principal credential not detected"
fi


echo ""