// ============================================================================
// DEPLOYMENT STACK EXAMPLE
// ============================================================================
// This template demonstrates Azure Deployment Stacks - a GA feature for
// managing the lifecycle of collections of Azure resources as a single unit.
//
// Deployment Stacks provide:
// - Unified management of related resources
// - Protection with deny settings (denyDelete, denyWriteAndDelete)
// - Cleanup behaviors (detach vs delete for unmanaged resources)
// - Atomic updates across resource groups
//
// DEPLOYMENT COMMANDS:
//
// Create/Update Stack:
//   az stack group create \
//     --name myapp-stack \
//     --resource-group myapp-rg \
//     --template-file examples/deployment-stack.bicep \
//     --parameters environment=prod projectName=myapp \
//     --deny-settings-mode denyDelete \
//     --delete-resources \
//     --delete-resource-groups \
//     --yes
//
// View Stack:
//   az stack group show \
//     --name myapp-stack \
//     --resource-group myapp-rg
//
// Delete Stack:
//   az stack group delete \
//     --name myapp-stack \
//     --resource-group myapp-rg \
//     --delete-all \
//     --yes
//
// ============================================================================

import {Env, Region} from '../types/common.bicep'
import {generateResourceName, buildTags, isProduction} from '../lib/helpers.bicep'
import {webTierRules} from '../lib/nsg-rules.bicep'

// ============================================================================
// PARAMETERS
// ============================================================================

@description('Environment identifier')
param environment Env = 'prod'

@description('Azure region')
param location Region = 'eastus'

@description('Project name')
@minLength(3)
@maxLength(20)
param projectName string

@description('Enable delete protection (recommended for production)')
param enableDeleteProtection bool = true

// ============================================================================
// VARIABLES
// ============================================================================

var tags = buildTags(environment, 'platform-team', projectName, 'STACK-001', null)

// ============================================================================
// RESOURCES - Managed by Deployment Stack
// ============================================================================

// 1. Network Security Group
module nsg '../modules/network/nsg.bicep' = {
  name: 'nsg-deployment'
  params: {
    input: {
      name: generateResourceName('nsg', projectName, environment, location)
      location: location
      rules: webTierRules
      tags: tags
    }
  }
}

// 2. Virtual Network
module vnet '../modules/network/vnet.bicep' = {
  name: 'vnet-deployment'
  params: {
    input: {
      name: generateResourceName('vnet', projectName, environment, location)
      location: location
      addressSpaces: ['10.0.0.0/16']
      subnets: [
        {
          name: 'app'
          prefix: '10.0.1.0/24'
          nsgId: nsg.outputs.nsgId
        }
        {
          name: 'data'
          prefix: '10.0.2.0/24'
          nsgId: null
        }
      ]
    }
  }
}

// 3. App Service
module app '../modules/app/appservice.bicep' = {
  name: 'app-deployment'
  params: {
    app: {
      name: generateResourceName('app', projectName, environment, location)
      location: location
      tier: isProduction(environment) ? 'premium' : 'basic'
      capacity: isProduction(environment) ? 3 : 1
      tags: {
        ...tags
        managedBy: 'deployment-stack'
      }
      ingress: {
        kind: 'publicIp'
        sku: 'Standard'
        dnsLabel: '${projectName}-${environment}'
      }
      diagnostics: null
      autoScale: isProduction(environment)
        ? {
            minCapacity: 3
            maxCapacity: 10
            defaultCapacity: 3
            scaleOutCpuThreshold: 75
            scaleInCpuThreshold: 25
          }
        : null
      enableDeleteLock: enableDeleteProtection
    }
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Deployment stack metadata')
output stackInfo object = {
  projectName: projectName
  environment: environment
  location: location
  deleteProtection: enableDeleteProtection
  managedResources: {
    nsg: nsg.outputs.nsgId
    vnet: vnet.outputs.vnetId
    app: app.outputs.appId
  }
}

@description('Application URL')
output appUrl string = 'https://${app.outputs.defaultHostname}'

@description('Managed resource count')
output resourceCount int = 3

@description('NSG resource ID')
output nsgId string = nsg.outputs.nsgId

@description('VNet resource ID')
output vnetId string = vnet.outputs.vnetId

@description('App Service resource ID')
output appId string = app.outputs.appId

@description('App Service principal ID for RBAC assignments')
output appPrincipalId string = app.outputs.principalId
