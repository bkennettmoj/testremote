#!/bin/bash

# This script uses the current az cli context and subscription to create a new state backend,
# and echoes the corresponding config file.
#
# MAKE SURE YOU RUN
# az account set -s $SUBSCRIPTION_ID
# Where $SUBSCRIPTION_ID is the id of the subscription you want the backend storage account to be created in.

set -e
echoerr() { printf "%s\n" "$*" >&2; }
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
blu=$'\e[1;34m'
mag=$'\e[1;35m'
cyn=$'\e[1;36m'
end=$'\e[0m'

FOLDER_NAME=${PWD##*/}

# Set defaults unless overridden
if [ -z "${TF_ENVIRONMENT_NAME+x}" ]; then TF_ENVIRONMENT_NAME="${FOLDER_NAME}" ; fi
if [ -z "${PROJECT_NAME+x}" ];      then PROJECT_NAME="$(basename "$(git rev-parse --show-toplevel)")" ; fi

RESOURCE_GROUP_NAME=dso-terraform-state
TF_STATE_KEY="${PROJECT_NAME}.${TF_ENVIRONMENT_NAME}.tfstate"
AZURE_ACCOUNT_NAME=$(az account show --query "name")
AZURE_ACCOUNT_ID=$(az account show --query "id")
AZURE_TENANT_ID=$(az account show --query "tenantId")


echoerr ""
echoerr "=============================="
echoerr "${red}WARNING${end} make sure you have run"
echoerr "az account set -s \$SUBSCRIPTION_ID ${end}"
echoerr "Where ${SUBSCRIPTION_ID} is the id of the subscription you want the backend storage account to be created in."
echoerr "This script does not set this automatically."
echoerr "${red}Check the azure sub below is the correct one.${end}"
echoerr "=============================="
echoerr ""
echoerr "Configuring the terraform backend for environment ${yel}${TF_ENVIRONMENT_NAME}${end} in azure sub ${red}${AZURE_ACCOUNT_NAME}${end},"
echoerr "using the storage container name ${grn}${PROJECT_NAME}${end} and the state key ${grn}${TF_STATE_KEY}${end}."
echoerr "This script will create azure resources if they do not exist, and just use them if they do."
echoerr ""

if [ "${DSO_DONT_WAIT_FOR_CONFIRMATION}" == "true" ] ; then
    echoerr "Skipping user confirmation."
else

  read -r -p "Proceed? [y/N] " response
  if [[ "${response}" =~ ^([yY][eE][sS]|[yY])$ ]]
    then
        echoerr ""
    else
        exit 1
    fi

fi

echoerr "Get or create resource group..."
set +e
az group show --name "${RESOURCE_GROUP_NAME}" > /dev/null 2>&1

if ! [ "$(az group show --name "${RESOURCE_GROUP_NAME}" > /dev/null)" = "0" ]; then
  set -e
  az group create --name "${RESOURCE_GROUP_NAME}" --location uksouth > /dev/null
  echoerr "Group created."
else
  set -e
  echoerr "   existing group found."
fi

# If there is more than one storage account in the resource group, we won't be able to figure out
# which to put the state file in, so we have to fail and exit.
echoerr "Get or create storage account..."
STORAGE_ACCOUNT_LIST=$(az storage account list --resource-group "${RESOURCE_GROUP_NAME}" --query "[].{name:name}" -o tsv )
STORAGE_ACCOUNT_COUNT=$(echo "${STORAGE_ACCOUNT_LIST}" | wc -w | xargs)
if [ "${STORAGE_ACCOUNT_COUNT}" -gt "1" ]; then
  echoerr ""
  echoerr "There should only be one storage account in the terraform state resource group."
  echoerr "There are ${STORAGE_ACCOUNT_COUNT}"
  echoerr "${STORAGE_ACCOUNT_LIST}"
  exit 1
fi

if [ "${STORAGE_ACCOUNT_COUNT}" = "0" ]; then
  az storage account create --resource-group "${RESOURCE_GROUP_NAME}" --name dsotstate"${RANDOM}${RANDOM}${RANDOM}" --sku Standard_LRS --encryption-services blob >/dev/null
  echoerr "Storage account created."
else
  echoerr "   existing account found."
fi

STORAGE_ACCOUNT_NAME=$(az storage account list --resource-group "${RESOURCE_GROUP_NAME}" --query "[].{name:name}" -o tsv )

echoerr "Get account key for use in storage container creation"
ACCOUNT_KEY=$(az storage account keys list --resource-group "${RESOURCE_GROUP_NAME}" --account-name "${STORAGE_ACCOUNT_NAME}" --query '[0].value' -o tsv)
echoerr "  key retrieved."

echoerr "Check to see if container already exists..."
if az storage container show --name "${PROJECT_NAME}" --account-name "${STORAGE_ACCOUNT_NAME}" > /dev/null 2>&1 ; then
  echoerr "  container already exists."
else
  echoerr "  creating container..."
  az storage container create --name "${PROJECT_NAME}" --account-name "${STORAGE_ACCOUNT_NAME}" --account-key "${ACCOUNT_KEY}"  > /dev/null
  echoerr "    container created."
fi

echoerr "Check to see if blob already exists..."
if az storage blob show -c "${PROJECT_NAME}" -n "${TF_STATE_KEY}" --account-name "${STORAGE_ACCOUNT_NAME}" > /dev/null 2>&1 ; then
  BLOB_ALREADY_EXISTED=true
fi

echoerr "  done verifying azure backend resources."

if [ -f ./backend.tf ]; then
    cp ./backend.tf ./backend.tf."${RANDOM}".backup
fi

comment="DO NOT DELETE! While these values dont do anything in terraform unless you're using a managed identity, we store them for dso internal use."

echo "terraform {"                                                         > ./backend.tf
echo "  backend \"azurerm\" {"                                             >> ./backend.tf
echo "    subscription_id       = $AZURE_ACCOUNT_ID # $comment"            >> ./backend.tf
echo "    tenant_id             = $AZURE_TENANT_ID # $comment"             >> ./backend.tf
echo "    resource_group_name   = \"dso-terraform-state\""                 >> ./backend.tf
echo "    storage_account_name  = \"$STORAGE_ACCOUNT_NAME\""               >> ./backend.tf
echo "    key                   = \"$TF_STATE_KEY\""                       >> ./backend.tf
echo "    container_name        = \"$PROJECT_NAME\""                       >> ./backend.tf
echo "  }"                                                                 >> ./backend.tf
echo "}"                                                                   >> ./backend.tf
         
echoerr ""         
echoerr DSO-standard terraform azure backend has been configured, and ./backend.tf has been created:-
echoerr ""

cat ./backend.tf
echoerr ""

if [ "${BLOB_ALREADY_EXISTED}" = "true" ]; then
  echoerr "${yel}Warning - state container already existed."
  echoerr "If this is a new environment/backend, ensure that you haven't specified a location with existing state.${end}"
  echo -ne '\007'
fi

echoerr "Dont forget to check backend.tf in, so that other users point to the correct state for your environment.${end}"
echoerr "You can now run terraform init."
