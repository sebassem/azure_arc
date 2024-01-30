@description('Name of the VNET')
param virtualNetworkName string = 'AIO-Demo-VNET'

@description('Name of the subnet in the virtual network')
param subnetName string = 'Subnet'

@description('Name of the Network Security Group')
param networkSecurityGroupName string = 'AIO-Demo-NSG'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('the Azure Bastion host name')
param bastionHostName string = 'AIO-Demo-Bastion'

@description('Choice to deploy Bastion to connect to the client VM')
param deployBastion bool


var publicIpAddressName = '${bastionHostName}-PIP'
var bastionSubnetName = 'AzureBastionSubnet'
var bastionSubnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, bastionSubnetName)
var subnetAddressPrefix = '10.1.0.0/24'
var addressPrefix = '10.1.0.0/16'
var bastionName = concat(bastionHostName)
var bastionSubnetIpPrefix = '10.1.1.64/26'


resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetIpPrefix
        }
      }
    ]
  }
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2019-02-01' = {
  name: networkSecurityGroupName
  location: location
}


resource networkSecurityGroupName_allow_RDP_3389 'Microsoft.Network/networkSecurityGroups/securityRules@2022-05-01' = if (deployBastion) {
  parent: networkSecurityGroup
  name: 'allow_RDP_3389'
  properties: {
    priority: 1001
    protocol: 'TCP'
    access: 'Allow'
    direction: 'Inbound'
    sourceAddressPrefix: bastionSubnetIpPrefix
    sourcePortRange: '*'
    destinationAddressPrefix: '*'
    destinationPortRange: '3389'
  }
}

resource publicIpAddress 'Microsoft.Network/publicIpAddresses@2022-07-01' = if (deployBastion == true) {
  name: publicIpAddressName
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
  sku: {
    name: ((!deployBastion) ? 'Basic' : 'Standard')
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2022-07-01' = if (deployBastion) {
  name: bastionName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: bastionSubnetRef
          }
          publicIPAddress: {
            id: publicIpAddress.id
          }
        }
      }
    ]
  }
  dependsOn: [
    virtualNetwork

  ]
}
