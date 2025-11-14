@description('Name of the Logic App')
param logicAppName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Tags to apply to resources')
param tags object = {
  Environment: 'Production'
  Purpose: 'ADF-Integration'
  ManagedBy: 'Bicep'
}

@description('Logic App SKU')
@allowed([
  'Standard'
  'Consumption'
])
param sku string = 'Consumption'

@description('Azure subscription ID where Data Factory is located')
param dataFactorySubscriptionId string = subscription().subscriptionId

@description('Resource group where Data Factory is located')
param dataFactoryResourceGroup string = resourceGroup().name

@description('Name of the Azure Data Factory')
param dataFactoryName string

@description('Name of the default pipeline to trigger')
param defaultPipelineName string = 'YourPipelineName'

// Logic App resource
resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: logicAppName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        subscriptionId: {
          type: 'string'
          defaultValue: dataFactorySubscriptionId
        }
        resourceGroupName: {
          type: 'string'
          defaultValue: dataFactoryResourceGroup
        }
        dataFactoryName: {
          type: 'string'
          defaultValue: dataFactoryName
        }
        pipelineName: {
          type: 'string'
          defaultValue: defaultPipelineName
        }
      }
      triggers: {
        manual: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {
              type: 'object'
              properties: {
                pipelineParameters: {
                  type: 'object'
                  description: 'Optional parameters to pass to the ADF pipeline'
                }
              }
            }
          }
        }
      }
      actions: {
        Create_ADF_Pipeline_Run: {
          type: 'Http'
          inputs: {
            method: 'POST'
            uri: 'https://management.azure.com/subscriptions/@{parameters(\'subscriptionId\')}/resourceGroups/@{parameters(\'resourceGroupName\')}/providers/Microsoft.DataFactory/factories/@{parameters(\'dataFactoryName\')}/pipelines/@{parameters(\'pipelineName\')}/createRun?api-version=2018-06-01'
            authentication: {
              type: 'ManagedServiceIdentity'
              audience: 'https://management.azure.com/'
            }
            body: '@triggerBody()?[\'pipelineParameters\']'
          }
          runAfter: {}
        }
        Parse_Response: {
          type: 'ParseJson'
          inputs: {
            content: '@body(\'Create_ADF_Pipeline_Run\')'
            schema: {
              type: 'object'
              properties: {
                runId: {
                  type: 'string'
                }
              }
            }
          }
          runAfter: {
            Create_ADF_Pipeline_Run: [
              'Succeeded'
            ]
          }
        }
        Response: {
          type: 'Response'
          kind: 'Http'
          inputs: {
            statusCode: 202
            body: {
              message: 'ADF Pipeline triggered successfully'
              runId: '@body(\'Parse_Response\')?[\'runId\']'
              dataFactory: '@parameters(\'dataFactoryName\')'
              pipeline: '@parameters(\'pipelineName\')'
            }
          }
          runAfter: {
            Parse_Response: [
              'Succeeded'
            ]
          }
        }
      }
    }
  }
}

// Output the Logic App's managed identity principal ID for RBAC assignment
output logicAppName string = logicApp.name
output logicAppId string = logicApp.id
output managedIdentityPrincipalId string = logicApp.identity.principalId
output logicAppCallbackUrl string = listCallbackUrl('${logicApp.id}/triggers/manual', '2019-05-01').value
