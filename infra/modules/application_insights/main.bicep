// ------------------
//    PARAMETERS
// ------------------

@description('The name of the Application Insights component')
@minLength(1)
@maxLength(260)
param name string

@description('The Azure region where the Application Insights component will be created')
param location string

@description('The resource ID of the Log Analytics workspace used for workspace-based ingestion')
@minLength(1)
param workspaceResourceId string

@description('Tags applied to the Application Insights component')
param tags object = {}

// ------------------
//    RESOURCES
// ------------------

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspaceResourceId
  }
}

// ------------------
//    OUTPUTS
// ------------------

@description('The resource ID of the Application Insights component')
output id string = applicationInsights.id

@description('The name of the Application Insights component')
output name string = applicationInsights.name

@description('The connection string of the Application Insights component')
output connectionString string = applicationInsights.properties.ConnectionString
