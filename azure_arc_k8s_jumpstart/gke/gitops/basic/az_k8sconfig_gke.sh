#!/bin/sh
# <--- Change the following environment variables according to your Azure service principal name --->
echo "Exporting environment variables"
export appId='<Your Azure service principal name>'
export password='<Your Azure service principal password>'
export tenantId='<Your Azure tenant ID>'
export resourceGroup='<Azure resource group name>'
export arcClusterName='<The name of your k8s cluster as it will be shown in Azure Arc>'
export appClonedRepo='<The URL for the "Arc Jumpstart" forked GitHub repository>'
export namespace='hello-arc'

# Installing Helm 3
echo "Installing Helm 3"
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Installing Azure CLI & Azure Arc Extensions
echo "Installing Azure CLI & Azure Arc Extensions"
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login to Azure
echo "Log in to Azure with Service Principal"
az login --service-principal --username $appId --password=$password --tenant $tenantId

# Create a namespace for your app & ingress resources
kubectl create ns $namespace

# Add the official stable repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Use Helm to deploy an NGINX ingress controller
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace $namespace

# Create GitOps config for Hello-Arc app
echo "Creating GitOps config for Hello-Arc app"
az k8s-configuration flux create \
--cluster-name $arcClusterName \
--resource-group $resourceGroup \
--name config-helloarc \
--namespace $namespace \
--cluster-type connectedClusters \
--scope namespace \
--url $appClonedRepo \
--branch main --sync-interval 3s \
--kustomization name=app path=./hello-arc/yaml

# Create GitOps config for Hello-Arc Ingress
echo "Creating GitOps config for Hello-Arc Ingress"
az k8s-configuration flux create \
--cluster-name $arcClusterName \
--resource-group $resourceGroup \
--name config-helloarc-ingress \
--namespace $namespace \
--cluster-type connectedClusters \
--scope namespace \
--url $appClonedRepo \
--branch main \
--kustomization name=app path=./hello-arc/ingress
