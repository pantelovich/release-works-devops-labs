targetScope = 'resourceGroup'

@description('Unique lowercase app name in your lab resource group.')
@minLength(4)
@maxLength(24)
param appName string

@description('Public Linux AMD64 image reference including its sha256 digest.')
param imageRef string

resource environment 'Microsoft.App/managedEnvironments@2025-01-01' = {
  name: '${appName}-env'
  location: resourceGroup().location
  properties: {
    appLogsConfiguration: {
      destination: 'none'
    }
  }
}

resource app 'Microsoft.App/containerApps@2025-01-01' = {
  name: appName
  location: resourceGroup().location
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      activeRevisionsMode: 'Multiple'
      ingress: {
        external: true
        targetPort: 8080
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
    }
    template: {
      revisionSuffix: 'baseline'
      containers: [
        {
          name: 'api'
          image: imageRef
          env: [
            { name: 'RELEASE_VERSION', value: 'v1' }
            { name: 'RELEASE_HEALTH', value: 'healthy' }
          ]
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          probes: [
            {
              type: 'Readiness'
              httpGet: {
                path: '/healthz'
                port: 8080
              }
              initialDelaySeconds: 2
              periodSeconds: 5
              timeoutSeconds: 2
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 1
      }
    }
  }
}

output fqdn string = app.properties.configuration.ingress.fqdn
output baselineRevision string = app.properties.latestRevisionName
