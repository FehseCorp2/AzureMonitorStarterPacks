param functionname string
param location string
param Tags object
param userManagedIdentity string
param userManagedIdentityClientId string
param packsUserManagedId string
param storageAccountName string
param filename string = 'discovery.zip'
param sasExpiry string = dateTimeAdd(utcNow(), 'PT2H')
param lawresourceid string
param appInsightsLocation string
param extraTags object = {}
var discoveryContainerName = 'discovery'
var tempfilename = '${filename}.tmp'
param apiManagementKey string= base64(newGuid())

var sasConfig = {
  signedResourceTypes: 'sco'
  signedPermission: 'r'
  signedServices: 'b'
  signedExpiry: sasExpiry
  signedProtocol: 'https'
  keyToSign: 'key2'
}

resource discoveryStorage 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'deployscript-MonstarPacks'
  dependsOn: [
    azfunctionsiteconfig
  ]
  tags: Tags
  location: location
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.42.0'
    timeout: 'PT5M'
    retentionInterval: 'PT1H'
    environmentVariables: [
      {
        name: 'AZURE_STORAGE_ACCOUNT'
        value: discoveryStorage.name
      }
      {
        name: 'AZURE_STORAGE_KEY'
        secureValue: discoveryStorage.listKeys().keys[0].value
      }
      {
        name: 'CONTENT'
        value: loadFileAsBase64('../../backend.zip')
      }
    ]
    scriptContent: 'echo "$CONTENT" > ${tempfilename} && cat ${tempfilename} | base64 -d > ${filename} && az storage blob upload -f ${filename} -c ${discoveryContainerName} -n ${filename} --overwrite '
  }
}

resource serverfarm 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: '${functionname}-farm'
  location: location
  tags: Tags
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
    size: 'Y1'
    family: 'Y'
    capacity: 0
  }
  kind: 'functioapp'
  properties: {
    perSiteScaling: false
    elasticScaleEnabled: false
    maximumElasticWorkerCount: 1
    isSpot: false
    reserved: false
    isXenon: false
    hyperV: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    zoneRedundant: false
  }
}
resource azfunctionsite 'Microsoft.Web/sites@2021-03-01' = {
  name: functionname
  location: location
  kind: 'functionapp'
  tags: Tags
  identity: {
      type: 'UserAssigned'
      userAssignedIdentities: {
          '${userManagedIdentity}': {}
      }
  }  
  properties: {
      enabled: true      
      hostNameSslStates: [
          {
              name: '${functionname}.azurewebsites.net'
              sslState: 'Disabled'
              hostType: 'Standard'
          }
          {
              name: '${functionname}.azurewebsites.net'
              sslState: 'Disabled'
              hostType: 'Repository'
          }
      ]
      serverFarmId: serverfarm.id
      reserved: false
      isXenon: false
      hyperV: false
      siteConfig: {
          numberOfWorkers: 1
          acrUseManagedIdentityCreds: false
          alwaysOn: false
          ipSecurityRestrictions: [
              {
                  ipAddress: 'Any'
                  action: 'Allow'
                  priority: 1
                  name: 'Allow all'
                  description: 'Allow all access'
              }
          ]
          scmIpSecurityRestrictions: [
              {
                  ipAddress: 'Any'
                  action: 'Allow'
                  priority: 1
                  name: 'Allow all'
                  description: 'Allow all access'
              }
          ]
          http20Enabled: false
          functionAppScaleLimit: 200
          minimumElasticInstanceCount: 0
          minTlsVersion: '1.2'       
      }
      scmSiteAlsoStopped: false
      clientAffinityEnabled: false
      clientCertEnabled: false
      clientCertMode: 'Required'
      hostNamesDisabled: false
      containerSize: 1536
      dailyMemoryTimeQuota: 0
      httpsOnly: false
      redundancyMode: 'None'
      storageAccountRequired: false
      keyVaultReferenceIdentity: 'SystemAssigned'

  }
}

resource azfunctionsiteconfig 'Microsoft.Web/sites/config@2021-03-01' = {
  name: 'appsettings'
  parent: azfunctionsite
  properties: {
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING:'DefaultEndpointsProtocol=https;AccountName=${discoveryStorage.name};AccountKey=${listKeys(discoveryStorage.id, discoveryStorage.apiVersion).keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
    AzureWebJobsStorage:'DefaultEndpointsProtocol=https;AccountName=${discoveryStorage.name};AccountKey=${listKeys(discoveryStorage.id, discoveryStorage.apiVersion).keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
    WEBSITE_CONTENTSHARE : discoveryStorage.name
    FUNCTIONS_WORKER_RUNTIME:'powershell'
    FUNCTIONS_EXTENSION_VERSION:'~4'
    ResourceGroup: resourceGroup().name
    SolutionTag: Tags['MonitorStarterPacks']
    APPINSIGHTS_INSTRUMENTATIONKEY: reference(appinsights.id, '2020-02-02-preview').InstrumentationKey
    APPLICATIONINSIGHTS_CONNECTION_STRING: 'InstrumentationKey=${reference(appinsights.id, '2020-02-02-preview').InstrumentationKey}'
    ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
    MSI_CLIENT_ID: userManagedIdentityClientId
    PacksUserManagedId: packsUserManagedId
  }
}

resource deployfunctions 'Microsoft.Web/sites/extensions@2021-02-01' = {
  parent: azfunctionsite
  dependsOn: [
    deploymentScript
  ]
  
  name: 'MSDeploy'
  properties: {
    packageUri: '${discoveryStorage.properties.primaryEndpoints.blob}${discoveryContainerName}/${filename}?${(discoveryStorage.listAccountSAS(discoveryStorage.apiVersion, sasConfig).accountSasToken)}'
  }
}

resource appinsights 'Microsoft.Insights/components@2020-02-02' = {
  name: functionname
  tags: Tags
  location: appInsightsLocation
  kind: 'web'
  properties: {
    Application_Type: 'web'
    //ApplicationId: guid(functionname)
    //Flow_Type: 'Redfield'
    //Request_Source: 'IbizaAIExtension'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    WorkspaceResourceId: lawresourceid
  }
}

var keyName = 'monitoringKey'

resource monitoringkey 'Microsoft.Web/sites/host/functionKeys@2022-03-01' = { 
  dependsOn: [ 
    azfunctionsiteconfig 
  ]
  tags: Tags
  name: '${functionname}/default/${keyName}'  
  properties: {  
    name: keyName  
    value: apiManagementKey
  }  
} 

