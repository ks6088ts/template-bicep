// ------------------
//    PARAMETERS
// ------------------

@description('The name of the parent Azure AI Foundry account')
@minLength(2)
@maxLength(59)
param parentAccountName string

@description('The name of the model deployment')
@minLength(1)
@maxLength(64)
param name string

@description('The model name to deploy')
@minLength(1)
@maxLength(128)
param modelName string

@description('The model version to deploy (optional)')
param modelVersion string = ''

@description('The model format to deploy')
@minLength(1)
@maxLength(32)
param modelFormat string = 'OpenAI'

@description('The SKU name for the model deployment')
@minLength(1)
@maxLength(64)
param skuName string = 'GlobalStandard'

@description('The SKU capacity for the model deployment')
@minValue(1)
param skuCapacity int = 50

@description('The Responsible AI policy name (optional)')
param raiPolicyName string = ''

// ------------------
//    RESOURCES
// ------------------

// NOTE: API version pinned to `2025-06-01` to match the parent Foundry account module and the
// foundry-samples `00-basic` working sample. Mixing API versions across account/project/deployment
// resources has been observed to cause 500 InternalServerError. See foundry-samples issue #236.
resource parentAccount 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
  name: parentAccountName
}

resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: parentAccount
  name: name
  sku: {
    name: skuName
    capacity: skuCapacity
  }
  properties: {
    model: {
      format: modelFormat
      name: modelName
      ...(empty(modelVersion) ? {} : {
        version: modelVersion
      })
    }
    ...(empty(raiPolicyName) ? {} : {
      raiPolicyName: raiPolicyName
    })
  }
}

// ------------------
//    OUTPUTS
// ------------------

@description('The resource ID of the model deployment')
output id string = modelDeployment.id

@description('The name of the model deployment')
output name string = modelDeployment.name

@description('The provisioning state of the model deployment')
output provisioningState string = modelDeployment.properties.provisioningState
