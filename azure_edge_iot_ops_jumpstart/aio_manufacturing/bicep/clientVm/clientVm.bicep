@description('The name of you Virtual Machine.')
param vmName string = 'AIO-Demo'

@description('Username for the Virtual Machine.')
param windowsAdminUsername string = 'arcdemo'

@description('Windows password for the Virtual Machine')
@secure()
param windowsAdminPassword string

@description('The Windows version for the VM. This will pick a fully patched image of this given Windows version.')
param windowsOSVersion string = '2022-datacenter-g2'

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

param resourceTags object = {
  Project: 'jumpstart_azure_aio'
}

@description('Deploy Windows Node for AKS Edge Essentials')
param windowsNode bool = false

@description('Kubernetes distribution')
@allowed([
  'k8s'
  'k3s'
])
param kubernetesDistribution string = 'k3s'

@maxLength(5)
@description('Random GUID')
param namingGuid string = toLower(substring(newGuid(), 0, 5))

@description('The name of the Azure Data Explorer cluster')
param adxClusterName string = 'aioadx${namingGuid}'

@description('The custom location RPO ID')
param customLocationRPOID string

@description('The base URL used for accessing artifacts and automation artifacts.')
param templateBaseUrl string

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool

@description('Override default RDP port using this parameter. Default is 3389. No changes will be made to the client VM.')
param rdpPort string = '3389'

var publicIpAddressName = '${vmName}-PIP'
var networkInterfaceName = '${vmName}-NIC'
var subnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
var osDiskType = 'Premium_LRS'
var PublicIPNoBastion = {
  id: publicIpAddress.id
}

resource publicIpAddress 'Microsoft.Network/publicIpAddresses@2023-02-01' = if (deployBastion == false) {
  name: publicIpAddressName
  location: location
  tags: resourceTags
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
  sku: {
    name: 'Basic'
  }
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: networkInterfaceName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetRef
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: ((!deployBastion) ? PublicIPNoBastion : null)
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: vmName
  location: location
  tags: resourceTags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        name: '${vmName}-OSDisk'
        caching: 'ReadWrite'
        createOption: 'fromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
      }
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: windowsOSVersion
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
    osProfile: {
      computerName: vmName
      adminUsername: windowsAdminUsername
      adminPassword: windowsAdminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: false
      }
    }
  }
}

resource Bootstrap 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
  parent: vm
  name: 'Bootstrap'
  location: location
  tags: {
    displayName: 'Run Bootstrap'
  }
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      fileUris: [
        uri(templateBaseUrl, 'artifacts/PowerShell/Bootstrap.ps1')
      ]
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File Bootstrap.ps1 -adminUsername ${windowsAdminUsername} -adminPassword ${windowsAdminPassword} -spnClientId ${spnClientId} -spnClientSecret ${spnClientSecret} -spnTenantId ${spnTenantId} -subscriptionId ${subscriptionId} -resourceGroup ${resourceGroup().name} -location ${location} -kubernetesDistribution ${kubernetesDistribution} -windowsNode ${windowsNode} -templateBaseUrl ${templateBaseUrl} -customLocationRPOID ${customLocationRPOID} -spnObjectId ${spnObjectId} -gitHubAccount ${githubAccount} -githubBranch ${githubBranch} -adxClusterName ${adxClusterName} -rdpPort ${rdpPort}'
    }
  }
}

resource InstallWindowsFeatures 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
  parent: vm
  name: 'InstallWindowsFeatures'
  dependsOn: [
    Bootstrap
  ]
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.77'
    autoUpgradeMinorVersion: true
    settings: {
      wmfVersion: 'latest'
      configuration: {
        url: uri(templateBaseUrl, 'artifacts/Settings/DSCInstallWindowsFeatures.zip')
        script: 'DSCInstallWindowsFeatures.ps1'
        function: 'InstallWindowsFeatures'
      }
    }
  }
}
