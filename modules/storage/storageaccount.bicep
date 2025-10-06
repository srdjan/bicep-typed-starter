// ============================================================================
// STORAGE ACCOUNT MODULE - Serverless storage with advanced type safety
// ============================================================================

import {Region, Diagnostics} from '../../types/common.bicep'

// ============================================================================
// TYPE DEFINITIONS - Discriminated unions for storage configuration
// ============================================================================

@description('Storage SKU tier selection')
type StorageSku = 'Standard_LRS' | 'Standard_GRS' | 'Standard_RAGRS' | 'Premium_LRS'

@description('Storage access tier for blob storage')
type AccessTier = 'Hot' | 'Cool'

@discriminator('kind')
@description('Storage kind configuration with tier-specific options')
type StorageKind =
  | {kind: 'BlobStorage', accessTier: AccessTier}
  | {kind: 'StorageV2', accessTier: AccessTier}
  | {kind: 'FileStorage'}
  | {kind: 'BlockBlobStorage'}

@description('Network access configuration')
@discriminator('mode')
type NetworkAccess =
  | {mode: 'public', allowedIpRanges: string[]?}
  | {mode: 'private', vnetId: string, subnetName: string}
  | {mode: 'disabled'}

@description('Storage account configuration')
type StorageConfig = {
  @minLength(3)
  @maxLength(24)
  name: string
  location: Region
  sku: StorageSku
  storageKind: StorageKind
  networkAccess: NetworkAccess
  enableHttpsOnly: bool?
  minimumTlsVersion: 'TLS1_2' | 'TLS1_3'?
  enableBlobVersioning: bool?
  enableContainerSoftDelete: bool?
  containerSoftDeleteRetentionDays: int?
  diagnostics: Diagnostics?
  tags: object
}

// ============================================================================
// PARAMETERS
// ============================================================================

@description('Storage account configuration')
param storage StorageConfig

// ============================================================================
// RESOURCES
// ============================================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storage.name
  location: storage.location
  sku: {
    name: storage.sku
  }
  kind: storage.storageKind.kind
  tags: storage.tags
  properties: {
    accessTier: storage.storageKind.kind == 'BlobStorage' || storage.storageKind.kind == 'StorageV2'
      ? storage.storageKind.accessTier
      : null
    supportsHttpsTrafficOnly: storage.enableHttpsOnly ?? true
    minimumTlsVersion: storage.minimumTlsVersion ?? 'TLS1_2'
    allowBlobPublicAccess: storage.networkAccess.mode == 'public'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: storage.networkAccess.mode == 'public' ? 'Allow' : 'Deny'
      ipRules: storage.networkAccess.mode == 'public' && storage.networkAccess.allowedIpRanges != null
        ? map(storage.networkAccess.allowedIpRanges, ip => {value: ip})
        : []
    }
  }
}

// Blob service with versioning and soft delete
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    isVersioningEnabled: storage.enableBlobVersioning ?? false
    deleteRetentionPolicy: {
      enabled: storage.enableContainerSoftDelete ?? false
      days: storage.containerSoftDeleteRetentionDays ?? 7
    }
  }
}

// Private endpoint for private network access
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = if (storage.networkAccess.mode == 'private') {
  name: '${storage.name}-pe'
  location: storage.location
  tags: storage.tags
  properties: {
    subnet: {
      id: storage.networkAccess.mode == 'private'
        ? '${storage.networkAccess.vnetId}/subnets/${storage.networkAccess.subnetName}'
        : ''
    }
    privateLinkServiceConnections: [
      {
        name: '${storage.name}-plsc'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: ['blob']
        }
      }
    ]
  }
}

// Diagnostic settings
module diagnostics '../monitor/diagnostics-storage.bicep' = if (storage.diagnostics != null) {
  name: 'diag-${uniqueString(storageAccount.id)}'
  params: {
    storageAccountId: storageAccount.id
    diag: storage.diagnostics!
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Storage account resource ID')
output storageId string = storageAccount.id

@description('Storage account name')
output storageName string = storageAccount.name

@description('Primary blob endpoint')
output blobEndpoint string = storageAccount.properties.primaryEndpoints.blob

@description('Primary file endpoint')
output fileEndpoint string = storageAccount.properties.primaryEndpoints.?file ?? ''

@description('Primary table endpoint')
output tableEndpoint string = storageAccount.properties.primaryEndpoints.?table ?? ''

@description('Primary queue endpoint')
output queueEndpoint string = storageAccount.properties.primaryEndpoints.?queue ?? ''

@description('Private endpoint ID (if configured)')
output privateEndpointId string = storage.networkAccess.mode == 'private' ? privateEndpoint.id : ''
