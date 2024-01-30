@description('The name of you Virtual Machine.')
param vmName string = 'AIO-Demo'

@description('Kubernetes distribution')
@allowed([
  'k8s'
  'k3s'
])
param kubernetesDistribution string = 'k3s'

@description('Username for the Virtual Machine.')
param windowsAdminUsername string = 'arcdemo'

@description('Windows password for the Virtual Machine')
@secure()
param windowsAdminPassword string

@description('The Windows version for the VM. This will pick a fully patched image of this given Windows version.')
param windowsOSVersion string = '2022-datacenter-g2'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool

@description('the Azure Bastion host name')
param bastionHostName string = 'AIO-Demo-Bastion'

@description('The size of the VM')
param vmSize string = 'Standard_D8s_v3'

@description('Unique SPN app ID')
param spnClientId string

@description('Unique SPN object ID')
param spnObjectId string

@description('Unique SPN password')
@minLength(12)
@maxLength(123)
@secure()
param spnClientSecret string

@description('Unique SPN tenant ID')
param spnTenantId string

@description('Azure subscription ID')
param subscriptionId string = subscription().subscriptionId

@description('Target GitHub account')
param githubAccount string = 'microsoft'

@description('Target GitHub branch')
param githubBranch string = 'main'

@description('Name of the VNET')
param virtualNetworkName string = 'AIO-Demo-VNET'

@description('Name of the subnet in the virtual network')
param subnetName string = 'Subnet'

@description('Name of the Network Security Group')
param networkSecurityGroupName string = 'AIO-Demo-NSG'

param resourceTags object = {
  Project: 'jumpstart_azure_aio'
}

@maxLength(5)
@description('Random GUID')
param namingGuid string = toLower(substring(newGuid(), 0, 5))

@description('Deploy Windows Node for AKS Edge Essentials')
param windowsNode bool = false

@description('Name of the storage account')
param aioStorageAccountName string = 'aiostg${namingGuid}'

@description('Name of the storage queue')
param storageQueueName string = 'aioqueue'

@description('Name of the event hub')
param eventHubName string = 'aiohub${namingGuid}'

@description('Name of the event hub namespace')
param eventHubNamespaceName string = 'aiohubns${namingGuid}'

@description('Name of the event grid namespace')
param eventGridNamespaceName string = 'aioeventgridns${namingGuid}'

@description('The name of the Azure Data Explorer cluster')
param adxClusterName string = 'aioadx${namingGuid}'

@description('The custom location RPO ID')
param customLocationRPOID string

@description('The name of the Azure Key Vault')
param akvName string = 'aioakv${namingGuid}'

@description('The name of the Azure Data Explorer Event Hub consumer group')
param eventHubConsumerGroupName string = 'cgadx${namingGuid}'

@description('The name of the Azure Data Explorer Event Hub production line consumer group')
param eventHubConsumerGroupNamePl string = 'cgadxpl${namingGuid}'

@description('Override default RDP port using this parameter. Default is 3389. No changes will be made to the client VM.')
param rdpPort string = '3389'

var templateBaseUrl = 'https://raw.githubusercontent.com/${githubAccount}/azure_arc/${githubBranch}/azure_edge_iot_ops_jumpstart/aio_manufacturing/bicep/'
module mgmtArtifactsAndPolicyDeployment 'mgmt/mgmtArtifacts.bicep' = {
  name: 'mgmtArtifactsAndPolicyDeployment'
  params: {
    deployBastion: deployBastion
    bastionHostName: bastionHostName
    networkSecurityGroupName: networkSecurityGroupName
    subnetName: subnetName
    virtualNetworkName: virtualNetworkName
    location: location
  }
}

module clientVm 'clientVm/clientVm.bicep' = {
  name: 'clientVmDeployment'
  dependsOn: [
    mgmtArtifactsAndPolicyDeployment
  ]
  params: {
    spnClientId: spnClientId
    spnClientSecret: spnClientSecret
    spnTenantId: spnTenantId
    spnObjectId: spnObjectId
    customLocationRPOID: customLocationRPOID
    deployBastion: deployBastion
    templateBaseUrl: templateBaseUrl
    windowsAdminPassword: windowsAdminPassword
    windowsAdminUsername: windowsAdminUsername
    adxClusterName: adxClusterName
    githubAccount: githubAccount
    githubBranch: githubBranch
    kubernetesDistribution: kubernetesDistribution
    location: location
    namingGuid: namingGuid
    rdpPort: rdpPort
    resourceTags: resourceTags
    subnetName: subnetName
    subscriptionId: subscriptionId
    virtualNetworkName: virtualNetworkName
    vmName: vmName
    vmSize: vmSize
    windowsNode: windowsNode
    windowsOSVersion: windowsOSVersion
  }
}

module storageAccount 'storage/storageAccount.bicep' = {
  name: 'storageAccount'
  params: {
    storageAccountName: aioStorageAccountName
    location: location
    storageQueueName: storageQueueName
  }
}

module eventHub 'data/eventHub.bicep' = {
  name: 'eventHub'
  params: {
    eventHubName: eventHubName
    eventHubNamespaceName: eventHubNamespaceName
    location: location
    eventHubConsumerGroupName: eventHubConsumerGroupName
    eventHubConsumerGroupNamePl: eventHubConsumerGroupNamePl
  }
}

module eventGrid 'data/eventGrid.bicep' = {
  name: 'eventGrid'
  params: {
    eventGridNamespaceName: eventGridNamespaceName
    eventHubResourceId: eventHub.outputs.eventHubResourceId
    queueName: storageQueueName
    storageAccountResourceId: storageAccount.outputs.storageAccountId
    namingGuid: namingGuid
    location: location
  }
}

module adxCluster 'data/dataExplorer.bicep' = {
  name: 'dataExplorer'
  params: {
    adxClusterName: adxClusterName
    location: location
    eventHubResourceId: eventHub.outputs.eventHubResourceId
    eventHubConsumerGroupName: eventHubConsumerGroupName
    eventHubName: eventHubName
    eventHubNamespaceName: eventHubNamespaceName
  }
}

module keyVault 'data/keyVault.bicep' = {
  name: 'keyVault'
  params: {
    tenantId: spnTenantId
    akvName: akvName
    location: location
  }
}

output windowsAdminUsername string = windowsAdminUsername
output adxEndpoint string = adxCluster.outputs.adxEndpoint
