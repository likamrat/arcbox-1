#!/bin/bash

# deployment flags

# required vars
azLocation=eastus
azResourceGroup=arcbox2

deployAKS=true

echo ******************************************************************
echo **                    Azure Arc in a Box                        **
echo ******************************************************************

# Collect user input
#echo Input a name for your resource group:
#read resourceGroupName

# Create a resource group.
az group create --name $azResourceGroup --location $azLocation

# Deploy AKS and Ubuntu Rancher (k3s)
az deployment group create --template-file kubernetesDeploy.json --parameters '{ \"policyName\": { \"value\": \"policy2\" } }'

