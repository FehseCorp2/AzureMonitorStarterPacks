param location string
param storageAccountName string
param sasExpiry string = dateTimeAdd(utcNow(), 'PT2H')
param filename string
param containerName string
//param resourceName string
param tags object
param userManagedIdentity string

var discoveryContainerName = 'discovery'


var tempfilename = 'download.tmp'
var sasConfig = {
  signedResourceTypes: 'sco'
  signedPermission: 'r'
  signedServices: 'b'
  signedExpiry: sasExpiry
  signedProtocol: 'https'
  keyToSign: 'key2'
}
resource packStorage 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

// resource deploymentScriptold 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
//   name: resourceName
//   tags: tags
//   location: location
//   kind: 'AzureCLI'
//   properties: {
//     azCliVersion: '2.26.1'
//     timeout: 'PT5M'
//     retentionInterval: 'PT1H'
//     environmentVariables: [
//       {
//         name: 'AZURE_STORAGE_ACCOUNT'
//         value: packStorage.name
//       }
//       {
//         name: 'AZURE_STORAGE_KEY'
//         secureValue: packStorage.listKeys().keys[0].value
//       }
//       {
//         name: 'CONTENT'
//         value: fileURL
//       }
//     ]
//     scriptContent: 'wget $CONTENT && az storage blob upload -f ${filename} -c ${containerName} -n ${filename} ' //--overwrite'
//   }
// }

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'deployscript-LinuxDiscovery'
  tags: tags
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userManagedIdentity}': {}
    }
  }
  properties: {
    azCliVersion: '2.42.0'
    timeout: 'PT5M'
    retentionInterval: 'PT1H'
    environmentVariables: [
      {
        name: 'AZURE_STORAGE_ACCOUNT'
        value: packStorage.name
      }
      // {
      //   name: 'AZURE_STORAGE_KEY'
      //   secureValue: packStorage.listKeys().keys[0].value
      // }
      {
        name: 'CONTENT'
        value: loadFileAsBase64('../Windows/discover.zip')
      }
    ]
    scriptContent: 'echo "$CONTENT" > ${tempfilename} && cat ${tempfilename} | base64 -d > ${filename} && az storage blob upload -f ${filename} -c ${discoveryContainerName} -n ${filename} --auth-mode login --overwrite true'
  }
}

output fileURL string = '${packStorage.properties.primaryEndpoints.blob}${containerName}/${filename}?${(packStorage.listAccountSAS(packStorage.apiVersion, sasConfig).accountSasToken)}'
