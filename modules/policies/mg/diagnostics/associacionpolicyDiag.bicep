targetScope = 'managementGroup'

param policyName string
param policyDisplayName string
param policyDescription string
// param policyLocation string
// param mgname string
// param subscriptionId string
// param userManagedIdentityResourceId string
param packtag string
param solutionTag string
param logAnalyticsWSResourceId string
param resourceType string// = 'Microsoft.Network/vpngateways'
param packtype string
param initiativeMember bool
// param instanceName string
// param assignmentLevel string
// param assignmentSuffix string
// param resourceTypes array

resource diagPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: 'AMP-${policyName}'
  properties: {
    description: 'AMP-${policyDescription}'
    displayName: 'AMP-${policyDisplayName}'
    metadata: {
      category: 'Monitoring'
      '${solutionTag}': packtag
      MonitoringPackType: packtype
      initiativeMember: initiativeMember
    }
    policyType: 'Custom'
    mode: 'Indexed'
    parameters: {
      tagName: {
        type: 'String'
        metadata: {
          displayName: 'Tag name'
          description: 'A tag to apply the association conditionally.'
        }
        defaultValue: solutionTag
      }
      tagValue: {
        type: 'String'
        metadata: {
          displayName: 'Tag value'
          description: 'The value of the tag.'
        }
        defaultValue: packtag
      }
      resourceType: {
        type: 'String'
        metadata: {
          displayName: 'Resource Type'
          description: 'The the full Microsoft.ResourceProvider/resourceType format of the resource type to apply the policy to.'
        }
        defaultValue: packtag
      }
      effect: {
        type: 'String'
        metadata: {
          displayName: 'Effect'
          description: 'Enable or disable the execution of the policy'
        }
        allowedValues: [
          'DeployIfNotExists'
          'Disabled'
        ]
        defaultValue: 'DeployIfNotExists'
      }
      logAnalyticsWSResourceId: {
        type: 'String'
        metadata: {
          displayName: 'LAW Id'
          description: 'The Id of the Log Analytics workspace.'
        }
        defaultValue: logAnalyticsWSResourceId
      }
    }
    policyRule: {
      if: {
        allOf: [
          {
            field: '[concat(\'tags[\', parameters(\'tagName\'), \']\')]' // No need to use an additional forward square bracket in the expressions as in ARM templates
            contains : '[parameters(\'tagValue\')]'
          }
          {
            field: 'type'
            equals: resourceType
          }
        ]
      }
      then: {
        effect: '[parameters(\'effect\')]'
        details: {
          roleDefinitionIds: [
            '/providers/microsoft.authorization/roleDefinitions/92aaf0da-9dab-42b6-94a3-d43ce8d16293'
          ]
          type: 'Microsoft.Insights/diagnosticSettings'
          existenceCondition: {
            allOf: [
              {
                count: {
                  field: 'Microsoft.Insights/diagnosticSettings/logs[*]'
                  where: {
                    allOf: [
                      {
                        field: 'Microsoft.Insights/diagnosticSettings/logs[*].enabled'
                        equals: true
                      }
                      {
                        field: 'microsoft.insights/diagnosticSettings/logs[*].categoryGroup'
                        equals: 'allLogs'
                      }
                    ]
                  }
                }
                equals: 1
              }
              {
                field: 'Microsoft.Insights/diagnosticSettings/workspaceId'
                equals: logAnalyticsWSResourceId
              }
            ]
          }
          deployment: {
            properties: {
              mode: 'incremental'
              template: {
                '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                contentVersion: '1.0.0.0'
                parameters: {
                  resourceType: {
                     type: 'string'
                  }
                  logAnalyticsWSResourceId: {
                    type: 'string'
                  }
                  packTag: {
                    type: 'string'
                  }
                  resourceName: {
                    type: 'string'
                  }
                }
                variables: {
                }
                resources: [
                  {
                  type: '${resourceType}/providers/diagnosticSettings'
                  name: '[concat(parameters(\'resourceName\'), \'/Microsoft.Insights/\', \'AMP-\', parameters(\'packTag\'))]'
                  apiVersion: '2021-05-01-preview'
                  properties: {
                    workspaceId: '[parameters(\'logAnalyticsWSResourceId\')]'
                    logs: [
                      {
                        categoryGroup: 'allLogs'
                        enabled: true
                      }
                    ]
                    // metrics: [
                    //   {
                    //     timeGrain: null
                    //     enabled: true
                    //     retentionPolicy: {
                    //       days: 0
                    //       enabled: false
                    //     }
                    //     category: 'AllMetrics'
                    //   }
                    // ]
                  }
                }
                ]
              }
              parameters: {
                resourceType: {
                  value: '[parameters(\'resourceType\')]'
                }
                logAnalyticsWSResourceId: {
                  value: '[parameters(\'logAnalyticsWSResourceId\')]'
                }
                packTag: {
                  value: '[parameters(\'tagValue\')]'
                }
                resourceName: {
                  value: '[field(\'name\')]'
                }
              }
            }
          }
        }
      }
    }
  }
}

// module policyassignment '../../../../modules/policies/mg/policiesDiag.bicep' = if(!initiativeMember) {
//   name: guid('AMP-${instanceName}-${policyName}')
//   params: {
//     location: policyLocation
//     mgname: mgname
//     packtag: packtag
//     policydefinitionId: diagPolicy.id
//     resourceType: resourceType
//     solutionTag: solutionTag
//     subscriptionId: subscriptionId 
//     userManagedIdentityResourceId: userManagedIdentityResourceId
//     assignmentLevel: assignmentLevel
//     policyType: 'diag'
//     assignmentSuffix: assignmentSuffix
//   }
// }

output policyId string = diagPolicy.id
