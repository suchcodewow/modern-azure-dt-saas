#!/bin/bash

source "./lib/_locations.lib"

YLW='\033[1;33m'
NC='\033[0m'

demand_answers() {
  if [ -f "$CREDS_FILE" ]
  then
      DT_BASEURL=$(cat $CREDS_FILE | jq -r '.DT_BASEURL')
      DT_API_TOKEN=$(cat $CREDS_FILE | jq -r '.DT_API_TOKEN')
      DASHBOARD_OWNER_EMAIL=$(cat $CREDS_FILE | jq -r '.DT_DASHBOARD_OWNER_EMAIL')
  fi

  clear
  echo "==================================================================="
  echo -e "${YLW}Please enter your Dynatrace credentials as requested below: ${NC}"
  echo "Press <enter> to keep the current value"
  echo "==================================================================="
  echo    "Dynatrace Base URL       (ex. https://ABC.live.dynatrace.com) "
  read -p "                         (current: $DT_BASEURL) : " DT_BASEURL_NEW
  read -p "Dynatrace API Token      (current: $DT_API_TOKEN) : " DT_API_TOKEN_NEW
  read -p "Your Email               (current: $DASHBOARD_OWNER_EMAIL) : " DASHBOARD_OWNER_EMAIL_NEW
  echo "==================================================================="
  echo ""

  DT_BASEURL=${DT_BASEURL_NEW:-$DT_BASEURL}
  DT_API_TOKEN=${DT_API_TOKEN_NEW:-$DT_API_TOKEN}
  DASHBOARD_OWNER_EMAIL=${DASHBOARD_OWNER_EMAIL_NEW:-$DASHBOARD_OWNER_EMAIL}
}

load_creds(){
  if [ -f "$CREDS_FILE" ]
  then
      DT_BASEURL=$(cat $CREDS_FILE | jq -r '.DT_BASEURL')
      DT_API_TOKEN=$(cat $CREDS_FILE | jq -r '.DT_API_TOKEN')
      DT_PAAS_TOKEN=$(cat $CREDS_FILE | jq -r '.DT_PAAS_TOKEN')
      DT_ENVIRONMENT_ID=$(cat $CREDS_FILE | jq -r '.DT_ENVIRONMENT_ID')
      AZURE_RESOURCE_GROUP=$(cat $CREDS_FILE | jq -r '.AZURE_RESOURCE_GROUP')
      AZURE_SP_NAME=$(cat $CREDS_FILE | jq -r '.AZURE_SP_NAME')
      AZURE_SUBSCRIPTION=$(cat $CREDS_FILE | jq -r '.AZURE_SUBSCRIPTION')
      AZURE_LOCATION=$(cat $CREDS_FILE | jq -r '.AZURE_LOCATION')
      RESOURCE_PREFIX=$(cat $CREDS_FILE | jq -r '.RESOURCE_PREFIX')
      AZURE_AKS_CLUSTER_NAME=$(cat $CREDS_FILE | jq -r '.AZURE_AKS_CLUSTER_NAME')
  else
    echo "ABORT: CREDS_FILE: $CREDS_FILE not found"
    exit 1
  fi
}

make_creds_file() {
  demand_answers

  DT_ENVIRONMENT_ID=$(echo $DT_BASEURL | awk -F"." '{ print $1 }' | awk -F"https://" '{ print $2 }')

  # pull out the DT_ENVIRONMENT_ID. DT_BASEURL will be one of these patterns
  if [[ $(echo $DT_BASEURL | grep "/e/" | wc -l) == *"1"* ]]; then
    #echo "Matched pattern: https://{your-domain}/e/{your-environment-id}"
    DT_ENVIRONMENT_ID=$(echo $DT_BASEURL | awk -F"/e/" '{ print $2 }')
  elif [[ $(echo $DT_BASEURL | grep ".live." | wc -l) == *"1"* ]]; then
    #echo "Matched pattern: https://{your-environment-id}.live.dynatrace.com"
    DT_ENVIRONMENT_ID=$(echo $DT_BASEURL | awk -F"." '{ print $1 }' | awk -F"https://" '{ print $2 }')
  elif [[ $(echo $DT_BASEURL | grep ".sprint." | wc -l) == *"1"* ]]; then
    #echo "Matched pattern: https://{your-environment-id}.sprint.dynatracelabs.com"
    DT_ENVIRONMENT_ID=$(echo $DT_BASEURL | awk -F"." '{ print $1 }' | awk -F"https://" '{ print $2 }')
  else
    echo "ERROR: No DT_ENVIRONMENT_ID pattern match to $DT_BASEURL"
    exit 1
  fi

  #remove trailing / if the have it
  if [ "${DT_BASEURL: -1}" == "/" ]; then
    #echo "removing / from DT_BASEURL"
    DT_BASEURL="$(echo ${DT_BASEURL%?})"
  fi

  HOSTNAME_MONOLITH=dt-orders-monolith
  HOSTNAME_SERVICES=dt-orders-services
  CLUSTER_NAME=dynatrace-$DT_ENVIRONMENT_ID-cluster
  AZURE_RESOURCE_GROUP=dynatrace-$DT_ENVIRONMENT_ID-resource-group
  AZURE_SP_NAME=$AZURE_RESOURCE_GROUP-sp
  AZURE_SUBSCRIPTION=$(az account show --query id --output tsv)

  # Display Azure subscription name
  echo "Using Azure Subscription: $(az account show --query name --output tsv)"
  # Confirm the token and URL are valid before writing file!
  echo -n "  Checking email address..."

  regex="^[a-z0-9!#\$%&'*+/=?^_\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?\$"

  
  if [[ $DASHBOARD_OWNER_EMAIL =~ $regex ]] ; then
      echo "email valid."
  else
    echo "FAIL."
      echo "  Email format error ($DASHBOARD_OWNER_EMAIL).  Please check and retry."
      echo ""
      exit 1
  fi

  echo -n "  Contacting Dynatrace tenant..."
  Integrity_Check=$(curl -s -o /dev/null -w "%{http_code}" "$DT_BASEURL/api/config/v1/frequentIssueDetection" -H "accept: application/json; charset=utf-8" -H "Content-Type: application/json; charset=utf-8" -H "Authorization: Api-Token $DT_API_TOKEN")
  if [ $Integrity_Check == "200" ]; then
    echo "valid."
  else
    echo "failed to connect."
    echo "  Check failed (status: $Integrity_Check).  Please check URL & Token and retry."
    echo ""
    exit 1
  fi

  cat $CREDS_TEMPLATE_FILE | \
  sed 's~DT_BASEURL_PLACEHOLDER~'"$DT_BASEURL"'~' | \
  sed 's~AZURE_SP_NAME_PLACEHOLDER~'"$AZURE_SP_NAME"'~' | \
  sed 's~AZURE_RESOURCE_GROUP_PLACEHOLDER~'"$AZURE_RESOURCE_GROUP"'~' | \
  sed 's~HOSTNAME_MONOLITH_PLACEHOLDER~'"$HOSTNAME_MONOLITH"'~' | \
  sed 's~HOSTNAME_SERVICES_PLACEHOLDER~'"$HOSTNAME_SERVICES"'~' | \
  sed 's~AZURE_AKS_CLUSTER_NAME_PLACEHOLDER~'"$CLUSTER_NAME"'~' | \
  sed 's~DT_API_TOKEN_PLACEHOLDER~'"$DT_API_TOKEN"'~' | \
  sed 's~AZURE_SUBSCRIPTION_PLACEHOLDER~'"$AZURE_SUBSCRIPTION"'~' | \
  sed 's~DT_ENVIRONMENT_ID_PLACEHOLDER~'"$DT_ENVIRONMENT_ID"'~' | \
  sed 's~DT_DASHBOARD_OWNER_EMAIL_PLACEHOLDER~'"$DASHBOARD_OWNER_EMAIL"'~' | \
  sed 's~DT_PAAS_TOKEN_PLACEHOLDER~'"$DT_API_TOKEN"'~' > $CREDS_FILE

  echo "Nice! Generated $CREDS_FILE"
  echo ""
}

create_azure_service_principal(){
  load_creds

  

  # delete sp if it exists
  echo "Provisioning Service Principal $AZURE_SP_NAME"
  ID=$(az ad sp list --query [] --filter "displayname eq '$AZURE_SP_NAME'" --query [].appId -o tsv)
  if ! [ -z "$ID" ]; then
      echo "Deleting old $AZURE_SP_NAME"
      #echo "Deleting existing $AZURE_SP_NAME within Azure"
      #az ad sp delete --id $ID
  fi

  echo "Adding $AZURE_SP_NAME to Azure and sending output to $AZURE_SP_JSON_FILE"
  SP_CREATE_RESULT=$(az ad sp create-for-rbac \
      --name "$AZURE_SP_NAME" \
      --role reader \
      --scopes "/subscriptions/$AZURE_SUBSCRIPTION")
  if [ -z "$SP_CREATE_RESULT" ]; then
    echo "Please enter credential file content here:"
    read SP_CREATE_RESULT
  fi
  echo $SP_CREATE_RESULT > "$AZURE_SP_JSON_FILE"

  echo "Generated Azure creds file $AZURE_SP_JSON_FILE"
      
}

create_service_principal_monaco_config() {

  MONACO_WORKSHOP_PROJECT=workshop
  MONACO_CONFIG_FOLDER="$MONACO_PROJECT_BASE_PATH/$MONACO_WORKSHOP_PROJECT"
  MONACO_JSON_FILE="$MONACO_CONFIG_FOLDER/azure-credentials/azure-credentials.json"
  MONACO_CONFIG_FILE="$MONACO_CONFIG_FOLDER/azure-credentials/config.yaml"

  AZURE_SP_APP_ID=$(cat $AZURE_SP_JSON_FILE | jq -r '.appId')
  AZURE_SP_DIRECTORY_ID=$(cat $AZURE_SP_JSON_FILE | jq -r '.tenant')
  AZURE_SP_KEY=$(cat $AZURE_SP_JSON_FILE | jq -r '.password')

  # A user maynot have permissions to make an Azure service principal
  # so only make the monaco config if they do
  if ! [ -z "$AZURE_SP_APP_ID" ]; then
    mkdir -p "$MONACO_CONFIG_FOLDER/azure-credentials"
    #echo "Generating $MONACO_CONFIG_FILE file used by monaco ***"
    echo "config:" > $MONACO_CONFIG_FILE
    echo "- credentials: \"azure-credentials.json\"" >> $MONACO_CONFIG_FILE
    echo "" >> $MONACO_CONFIG_FILE
    echo "credentials:" >> $MONACO_CONFIG_FILE
    echo "- name: \"azure-modernize-workshop\"" >> $MONACO_CONFIG_FILE
    echo "- appId: \"$AZURE_SP_APP_ID\"" >> $MONACO_CONFIG_FILE
    echo "- directoryId: \"$AZURE_SP_DIRECTORY_ID\"" >> $MONACO_CONFIG_FILE
    echo "- key: \"$AZURE_SP_KEY\"" >> $MONACO_CONFIG_FILE
     
    #echo ""
    #echo "*** Generated $MONACO_CONFIG_FILE file contents ***"
    #cat $MONACO_CONFIG_FILE

    #echo "*** Generating $MONACO_JSON_FILE file used by monaco ***"
    echo "{" > $MONACO_JSON_FILE
    echo "\"label\": \"{{ .name }}\"," >> $MONACO_JSON_FILE
    echo "\"appId\": \"{{ .appId }}\"," >> $MONACO_JSON_FILE
    echo "\"directoryId\": \"{{ .directoryId }}\"," >> $MONACO_JSON_FILE
    echo "\"active\": true," >> $MONACO_JSON_FILE
    echo "\"key\": \"{{ .key }}\"," >> $MONACO_JSON_FILE
    echo "\"autoTagging\": true," >> $MONACO_JSON_FILE
    echo "\"monitorOnlyTaggedEntities\": false," >> $MONACO_JSON_FILE
    echo "\"monitorOnlyTagPairs\": []" >> $MONACO_JSON_FILE
    echo "}" >> $MONACO_JSON_FILE

    #echo ""
    echo "Generated monaco config"
    #cat $MONACO_JSON_FILE
  else
    echo ""
    echo "*** Skipping Azure monitor setup due to invalid service principal file ***"
    echo ""
    echo "cat $AZURE_SP_JSON_FILE"
    #cat $AZURE_SP_JSON_FILE
    echo ""
  fi
}

download_monaco() {
    if [ $(uname -s) == "Darwin" ]
    then
        MONACO_BINARY="v1.6.0/monaco-darwin-10.12-amd64"
    else
        MONACO_BINARY="v1.6.0/monaco-linux-amd64"
    fi
    #echo "Getting MONACO_BINARY = $MONACO_BINARY"
    rm -f monaco
    wget -q -O monaco https://github.com/dynatrace-oss/dynatrace-monitoring-as-code/releases/download/$MONACO_BINARY
    chmod +x monaco
    echo "Installed monaco version: $(./monaco --version | tail -1)"
}

make_creds_file
create_azure_service_principal
#create_service_principal_monaco_config
#download_monaco