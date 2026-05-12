// ------------------
//    PARAMETERS
// ------------------

@description('The name of the diagnostic settings resource')
@minLength(1)
@maxLength(256)
param name string

@description('The resource ID of the Log Analytics workspace destination')
@minLength(1)
param workspaceResourceId string

@description('The target resource ID where diagnostic settings will be applied')
@minLength(1)
param targetResourceId string

@description('The diagnostic log settings to configure')
param logs array = [
  {
    categoryGroup: 'allLogs'
    enabled: true
  }
]

@description('The diagnostic metric settings to configure')
param metrics array = [
  {
    category: 'AllMetrics'
    enabled: true
  }
]

// ------------------
//    RESOURCES
// ------------------

#disable-next-line no-deployments-resources
resource diagnosticSettingsDeployment 'Microsoft.Resources/deployments@2024-03-01' = {
  name: take('diag-${uniqueString(targetResourceId, name)}', 64)
  properties: {
    mode: 'Incremental'
    expressionEvaluationOptions: {
      scope: 'inner'
    }
    parameters: {
      name: {
        value: name
      }
      workspaceResourceId: {
        value: workspaceResourceId
      }
      targetResourceId: {
        value: targetResourceId
      }
      logs: {
        value: logs
      }
      metrics: {
        value: metrics
      }
    }
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        name: {
          type: 'string'
        }
        workspaceResourceId: {
          type: 'string'
        }
        targetResourceId: {
          type: 'string'
        }
        logs: {
          type: 'array'
        }
        metrics: {
          type: 'array'
        }
      }
      resources: [
        {
          type: 'Microsoft.Insights/diagnosticSettings'
          apiVersion: '2021-05-01-preview'
          scope: '[parameters(\'targetResourceId\')]'
          name: '[parameters(\'name\')]'
          properties: {
            workspaceId: '[parameters(\'workspaceResourceId\')]'
            logs: '[parameters(\'logs\')]'
            metrics: '[parameters(\'metrics\')]'
          }
        }
      ]
      outputs: {
        id: {
          type: 'string'
          value: '[extensionResourceId(parameters(\'targetResourceId\'), \'Microsoft.Insights/diagnosticSettings\', parameters(\'name\'))]'
        }
        name: {
          type: 'string'
          value: '[parameters(\'name\')]'
        }
      }
    }
  }
}

// ------------------
//    OUTPUTS
// ------------------

@description('The resource ID of the diagnostic settings resource')
output id string = diagnosticSettingsDeployment.properties.outputs.id.value

@description('The name of the diagnostic settings resource')
output name string = diagnosticSettingsDeployment.properties.outputs.name.value
