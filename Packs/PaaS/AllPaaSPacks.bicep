targetScope = 'managementGroup'

@description('Name of the Action Group to be used or created.')
param actionGroupName string = ''
@description('Email receiver names to be used for the Action Group if being created.')
param emailreceivers array = []
@description('Email addresses to be used for the Action Group if being created.')
param emailreiceversemails array = []
@description('If set to true, a new Action group will be created')
param useExistingAG bool
@description('Name of the existing resource group to be used for the Action Group if existing.')
param existingAGRG string = ''
@description('location for the deployment.')
param location string //= resourceGroup().location
@description('Full resource ID of the log analytics workspace to be used for the deployment.')
param workspaceId string
param solutionTag string
param solutionVersion string
@description('Full resource ID of the data collection endpoint to be used for the deployment.')
param dceId string
@description('Full resource ID of the user managed identity to be used for the deployment')
param userManagedIdentityResourceId string
param mgname string // this the last part of the management group id
param subscriptionId string
param resourceGroupId string
param assignmentLevel string
param grafanaName string

module StorageAlerts './Storage/monitoring.bicep' = {
  name: 'StorageAlerts'
  params: {
    actionGroupName: actionGroupName
    assignmentLevel: assignmentLevel
    location: location
    mgname: mgname
    resourceGroupId: resourceGroupId
    solutionTag: solutionTag
    subscriptionId: subscriptionId
    useExistingAG: useExistingAG
    userManagedIdentityResourceId: userManagedIdentityResourceId
    workspaceId: workspaceId
    emailreceivers: emailreceivers
    emailreiceversemails: emailreiceversemails
    existingAGRG: existingAGRG
    packtag: 'Storage'
    grafanaName: grafanaName
    dceId: dceId
  }
}

module OpenAI './OpenAI/monitoring.bicep' = {
  name: 'OpenAIAlerts'
  params: {
    actionGroupName: actionGroupName
    assignmentLevel: assignmentLevel
    location: location
    mgname: mgname
    resourceGroupId: resourceGroupId
    solutionTag: solutionTag
    subscriptionId: subscriptionId
    useExistingAG: useExistingAG
    userManagedIdentityResourceId: userManagedIdentityResourceId
    workspaceId: workspaceId
    emailreceivers: emailreceivers
    emailreiceversemails: emailreiceversemails
    existingAGRG: existingAGRG
    packtag: 'OpenAI'
    grafanaName: grafanaName
    dceId: dceId
  }
}

