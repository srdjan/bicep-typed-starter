# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a **typed Bicep starter template** demonstrating Azure Infrastructure as Code with strong typing using Bicep's user-defined types feature. The project showcases discriminated unions, type safety, modular architecture, type/function imports with `@export/@import`, and Microsoft Graph extensions for Entra ID resources.

## Prerequisites

- Azure CLI (2.50.0+) with Bicep CLI (0.30.0+) installed
- `bicepconfig.json` enables experimental features: `userDefinedTypes` and `imports`
- PSRule for Azure (optional, for policy validation)

## Common Commands

### Bicep Operations
```bash
# Build/compile Bicep to ARM JSON
az bicep build --file main.bicep

# Deploy using parameter file (development)
az deployment group create \
  --resource-group <rg-name> \
  --template-file main.bicep \
  --parameters env/dev.bicepparam

# Deploy production with auto-scaling and locks
az deployment group create \
  --resource-group <rg-name> \
  --template-file main.bicep \
  --parameters env/prod.bicepparam

# Validate deployment
az deployment group validate \
  --resource-group <rg-name> \
  --template-file main.bicep \
  --parameters env/dev.bicepparam

# What-if analysis (dry-run)
az deployment group what-if \
  --resource-group <rg-name> \
  --template-file main.bicep \
  --parameters env/dev.bicepparam

# Lint and analyze
az bicep lint --file main.bicep

# Test individual module
az deployment group create \
  --resource-group test-rg \
  --template-file modules/network/vnet.bicep \
  --parameters input=@test-params.json
```

### Graph Extension Deployments (Tenant Scope)
```bash
# Deploy Entra ID group
az deployment tenant create \
  --template-file extensions/graph/entra-group.bicep \
  --parameters groupName='my-group'

# Deploy app registration with service principal
az deployment tenant create \
  --template-file extensions/graph/entra-app-registration.bicep \
  --parameters appName='my-app'
```

### Policy Validation
```bash
# Run PSRule validation
pwsh -Command "Assert-PSRule -InputPath . -Module PSRule.Rules.Azure"
```

## Architecture Patterns

### Type-Driven Design

This project uses **discriminated unions** and **union types** to enforce correctness at compile time:

- **Discriminated unions for ingress patterns**: `Ingress = PublicIpIngress | PrivateLinkIngress | AppGwIngress`
  - Each variant has a `kind` discriminator field
  - Type-safe access to variant-specific properties (e.g., `dnsLabel` only on `PublicIpIngress`)

- **Union types for enums**: `Env = 'dev' | 'test' | 'prod'`, `Region = 'eastus' | 'westeurope' | 'westus'`

- **Structural types for complex shapes**: `TagPolicy`, `AppConfig`, `VnetInput`, `Diagnostics`

### Module Organization

```
main.bicep              # Root orchestrator using imported types and functions
├── types/
│   └── common.bicep    # Central type library with @export decorator
├── lib/
│   ├── helpers.bicep   # Reusable functions (@export) for tags, naming, SKU mapping
│   ├── nsg-rules.bicep # Predefined NSG rule templates
│   └── transformations.bicep # Data transformation utilities
├── modules/
│   ├── network/        # Network resources (VNets, NSGs, App Gateway)
│   ├── app/           # App Service Plan and Web App with managed identity
│   ├── serverless/    # Function Apps with consumption/premium plans
│   ├── monitor/       # Diagnostic settings with comprehensive logging
│   ├── storage/       # Storage accounts with encryption and networking
│   ├── edge/          # Azure Front Door for global load balancing
│   ├── api/           # API Management for API gateway functionality
│   ├── data/          # PostgreSQL flexible server with HA
│   └── messaging/     # Event Hub namespaces and hubs
├── extensions/
│   └── graph/         # Microsoft Graph resources (Entra ID groups/apps) - tenant scope
├── env/               # Environment-specific .bicepparam files
├── examples/          # Usage examples (complete-deployment, serverless, app-hosting, etc.)
└── policy/            # PSRule validation rules
```

**Key architectural decisions**:
1. **Type imports with @export/@import**: Shared types defined in `types/common.bicep` and imported via `import {TypeName} from './types/common.bicep'` (requires Bicep 0.30+)
2. **Function library**: Reusable functions in `lib/helpers.bicep` for tag composition, naming conventions, SKU mapping, and environment-specific defaults
3. **Modules are composable**: Each module imports only the types it needs and exposes typed outputs
4. **Conditional deployment**: Uses `if` expressions for optional features: `module diag '...' = if (app.diagnostics!=null)`
5. **Tag composition**: Uses `buildTags()` function from helpers library for consistent tagging

### Type Import/Export Pattern (Modern Bicep)

This project uses Bicep's `@export/@import` feature (requires Bicep 0.30+ and `imports` experimental feature):

**Exporting types and functions** (`types/common.bicep`):
```bicep
@export()
@description('Environment identifier')
type Env = 'dev' | 'test' | 'prod'

@export()
@description('Discriminated union for ingress configuration')
@discriminator('kind')
type Ingress =
  | { kind: 'publicIp', sku: 'Basic' | 'Standard', dnsLabel: string? }
  | { kind: 'privateLink', vnetId: string, subnetName: string }
```

**Importing types** (`main.bicep` or modules):
```bicep
import {
  Env
  Region
  AppTier
  Ingress
  AppConfig
} from './types/common.bicep'

param env Env
param app AppConfig
```

**Importing functions** (`lib/helpers.bicep`):
```bicep
import {buildTags} from './lib/helpers.bicep'

var commonTags = buildTags(env, tags.owner, project, tags.costCenter, null)
```

**Benefits**:
- Single source of truth for types and functions
- Type safety across module boundaries
- Refactor once, update everywhere
- IntelliSense support for imported types
- No type redeclaration needed (unlike older Bicep versions)

### Type Patterns in Use

1. **Discriminated unions** (`Ingress`, `AppGatewayBackendTarget`): Pattern matching via `kind` field enables conditional logic
   - `publicIp`: Public internet access with optional DNS label
   - `privateLink`: Private endpoint with VNet integration (fully implemented)
   - `appGateway`: Application Gateway integration (structure defined)
2. **Optional properties** (`diagnostics?`, `costCenter?`, `capacity?`, `autoScale?`): Use `?` suffix for nullable fields
3. **Nested structural types**: `AppConfig` embeds `Ingress`, `Diagnostics`, `TagPolicy`, and `AutoScaleSettings`
4. **Parameter validation**: `@minLength`, `@maxLength`, `@minValue`, `@maxValue` decorators enforce constraints at type level
5. **Type composition**: Complex types built from simpler ones (e.g., `FrontDoorConfig` composes `FrontDoorOriginGroup` and `FrontDoorRoute`)
6. **Conditional resources**: Private endpoints, auto-scaling, diagnostics, and locks deploy conditionally based on configuration

### Parameter File Pattern

Environment-specific configurations use `.bicepparam` files with `using` directive:
- `env/dev.bicepparam` references `using 'main.bicep'` and provides all required parameters
- Enables type-safe parameterization with IntelliSense

### Extension Pattern (Microsoft Graph)

- `extensions/graph/*.bicep` files use `targetScope='tenant'` and `extension microsoftGraph`
- Deploy Entra ID resources (groups, app registrations) alongside Azure infrastructure
- Separate deployment commands (tenant scope vs. resource group scope)

## Working with This Codebase

### Adding New Resource Types
1. Define types in `types/common.bicep` with `@export()` decorator if shared across modules
2. Import types using `import {TypeName} from '../types/common.bicep'` in modules that need them
3. Use discriminated unions for polymorphic resources (follow `Ingress` or `AppGatewayBackendTarget` pattern)
4. Add `@description`, `@minLength`, `@maxLength`, `@minValue`, `@maxValue` decorators for all type properties
5. For complex type hierarchies, define supporting types first, then compose them (e.g., `FrontDoorOrigin` → `FrontDoorOriginGroup` → `FrontDoorConfig`)

### Adding New Modules
1. Create module in `modules/<category>/<name>.bicep`
2. Import needed types: `import {TypeName1, TypeName2} from '../../types/common.bicep'`
3. Import helper functions if needed: `import {buildTags, getSkuForTier} from '../../lib/helpers.bicep'`
4. Define module parameters using imported types with `@description` decorators
5. Export outputs with explicit types and descriptions
6. Reference in `main.bicep` or composition templates
7. Add usage example in `examples/` directory

### Using Helper Functions
The `lib/helpers.bicep` library provides reusable functions:
- `buildTags()`: Merge common tags with custom tags
- `generateResourceName()`: Standard naming convention for resources
- `getSkuForTier()`: Map abstract tier to Azure SKU configuration
- `getRetentionDaysForEnv()`: Environment-specific retention defaults
- `buildAutoScaleSettings()`: Generate auto-scale config based on environment
- `isProduction()`: Check if environment is production
- Import with: `import {functionName} from './lib/helpers.bicep'`

### Security Best Practices
- **Managed Identity**: All App Services have system-assigned identity enabled
- **TLS**: Minimum TLS 1.2 enforced on all web apps
- **FTPS**: Disabled by default (use HTTPS for deployments)
- **HTTP/2**: Enabled for better performance
- **Network Security**: Use NSG module to define network-level access controls
- **Private Endpoints**: Full support for Private Link ingress with VNet integration
- **Public Access Control**: Automatically disabled when using privateLink ingress
- **Resource Locks**: Optional `CanNotDelete` locks for production resources (set `enableDeleteLock: true`)

### Validation Strategy
- **Compile-time**: Bicep type system + parameter decorators enforce contracts
- **Pre-deployment**: `az deployment group validate` checks ARM API compliance
- **Policy**: PSRule validates against Azure Well-Architected Framework (see `policy/Rules/`)

### Common Type Errors
- **Missing discriminator**: Ensure union variants have unique `kind` values (e.g., `kind: 'publicIp' | 'privateLink' | 'appGateway'`)
- **Import path errors**: Use correct relative paths when importing types/functions (e.g., `'../../types/common.bicep'` from modules, `'./types/common.bicep'` from root)
- **Circular imports**: Avoid circular dependencies between type/function files
- **Null handling**: Use `!` non-null assertion operator when Bicep can't infer (`diag!.workspaceId`)
- **Capacity limits**: App Service capacity is capped at 30 instances via `@maxValue(30)`
- **Union type constraints**: Union members must share a single underlying primitive (all strings or all ints). Mixed unions like `'a' | 1` are invalid
- **Missing @export**: Types and functions must have `@export()` decorator to be imported by other files

## Module Catalog

The project includes production-ready modules for common Azure services:

### Compute & Hosting
- **App Service** (`modules/app/appservice.bicep`): Web apps with managed identity, auto-scaling, private endpoints, TLS enforcement
- **Function Apps** (`modules/serverless/functionapp.bicep`): Serverless compute with consumption/premium plans, VNet integration

### Networking
- **Virtual Network** (`modules/network/vnet.bicep`): VNets with subnets, delegations, NSG attachments
- **Network Security Groups** (`modules/network/nsg.bicep`): Typed security rules with priority validation
- **Application Gateway** (`modules/network/appgateway.bicep`): Layer 7 load balancer with WAF, health probes, routing rules
- **Azure Front Door** (`modules/edge/frontdoor.bicep`): Global CDN with origin groups, routes, health probes

### Data & Storage
- **Storage Accounts** (`modules/storage/storageaccount.bicep`): Blob/file storage with encryption, networking, lifecycle policies
- **PostgreSQL** (`modules/data/postgres-flexible.bicep`): Flexible server with HA, backup, VNet integration, database creation

### Integration
- **Event Hub** (`modules/messaging/eventhub.bicep`): Event streaming with namespace, hubs, consumer groups, auto-inflate
- **API Management** (`modules/api/apim.bicep`): API gateway with virtual network integration, client certificates

### Monitoring
- **Diagnostics** (`modules/monitor/diagnostics.bicep`): Log Analytics integration for App Service (6 log categories + metrics)
- **Storage Diagnostics** (`modules/monitor/diagnostics-storage.bicep`): Diagnostic settings for storage accounts

### Identity (Extensions)
- **Entra ID Groups** (`extensions/graph/entra-group.bicep`): Microsoft Graph extension for group creation
- **App Registrations** (`extensions/graph/entra-app-registration.bicep`): Service principals with federated credentials

All modules follow consistent patterns:
- Import types from `types/common.bicep`
- Use helper functions from `lib/helpers.bicep`
- Comprehensive `@description` decorators
- Typed inputs and outputs
- Conditional resource deployment

## Advanced Features

### Auto-Scaling
Configure CPU-based auto-scaling with the `autoScale` property:
```bicep
autoScale: {
  minCapacity: 2
  maxCapacity: 10
  defaultCapacity: 3
  scaleOutCpuThreshold: 75  // Scale out when CPU > 75%
  scaleInCpuThreshold: 25   // Scale in when CPU < 25%
}
```

### Private Link Integration
Deploy App Service with private endpoint access:
```bicep
ingress: {
  kind: 'privateLink'
  vnetId: '/subscriptions/.../virtualNetworks/vnet-hub'
  subnetName: 'private-endpoints'
}
```
This automatically:
- Disables public network access
- Creates a private endpoint in the specified subnet
- Enables VNet integration
- Routes all outbound traffic through VNet

### Resource Protection
Enable delete locks for production resources:
```bicep
enableDeleteLock: true  // Applies CanNotDelete lock to App Service and Plan
```

## Type System Philosophy

This project follows the principles outlined in [docs/BICEP_BEST_PRACTICES.md](docs/BICEP_BEST_PRACTICES.md):

1. **Treat types as your domain model** - Use UDTs for reuse and clarity
2. **Encode constraints in types, not prose** - Literal unions instead of @allowed comments
3. **Use nullability operators** - `.?`, `??`, `!` for safe optional handling
4. **Tagged unions for option sets** - Discriminated unions with `kind` field
5. **Type-first validation** - Push errors to compile time, not runtime

## Key Files

### Core Infrastructure
- [main.bicep](main.bicep) - Root orchestrator using imported types and functions
- [bicepconfig.json](bicepconfig.json) - Enables experimental features: `userDefinedTypes` and `imports`

### Type System
- [types/common.bicep](types/common.bicep) - Central type library with all shared types (Env, Region, Ingress, AppConfig, etc.)
- [lib/helpers.bicep](lib/helpers.bicep) - Reusable functions for tags, naming, SKU mapping, environment defaults
- [lib/nsg-rules.bicep](lib/nsg-rules.bicep) - Predefined NSG rule templates
- [lib/transformations.bicep](lib/transformations.bicep) - Data transformation utilities

### Parameter Files
- [env/dev.bicepparam](env/dev.bicepparam) - Development environment parameters
- [env/prod.bicepparam](env/prod.bicepparam) - Production environment with auto-scaling and locks
- [env/privatelink.bicepparam](env/privatelink.bicepparam) - Private Link configuration example

### Modules
- [modules/app/appservice.bicep](modules/app/appservice.bicep) - App Service with managed identity, security hardening, auto-scaling, private endpoints
- [modules/serverless/functionapp.bicep](modules/serverless/functionapp.bicep) - Azure Function Apps with consumption/premium plans
- [modules/network/vnet.bicep](modules/network/vnet.bicep) - Virtual Network with subnet configuration and delegations
- [modules/network/nsg.bicep](modules/network/nsg.bicep) - Network Security Group with typed rules
- [modules/network/appgateway.bicep](modules/network/appgateway.bicep) - Application Gateway with WAF support
- [modules/edge/frontdoor.bicep](modules/edge/frontdoor.bicep) - Azure Front Door for global load balancing
- [modules/api/apim.bicep](modules/api/apim.bicep) - API Management for API gateway functionality
- [modules/data/postgres-flexible.bicep](modules/data/postgres-flexible.bicep) - PostgreSQL flexible server with HA and backup
- [modules/storage/storageaccount.bicep](modules/storage/storageaccount.bicep) - Storage accounts with encryption and networking
- [modules/messaging/eventhub.bicep](modules/messaging/eventhub.bicep) - Event Hub namespaces with consumer groups
- [modules/monitor/diagnostics.bicep](modules/monitor/diagnostics.bicep) - Diagnostic settings for App Service
- [modules/monitor/diagnostics-storage.bicep](modules/monitor/diagnostics-storage.bicep) - Diagnostic settings for Storage

### Extensions
- [extensions/graph/entra-group.bicep](extensions/graph/entra-group.bicep) - Microsoft Graph extension for Entra ID groups
- [extensions/graph/entra-app-registration.bicep](extensions/graph/entra-app-registration.bicep) - Entra ID app registration with service principal

### Examples
- [examples/complete-deployment.bicep](examples/complete-deployment.bicep) - Full-featured deployment with NSG, VNet, App Service, auto-scaling, and locks
- [examples/nsg-example.bicep](examples/nsg-example.bicep) - Example NSG configuration with web app rules
- [examples/app-hosting-stack.bicep](examples/app-hosting-stack.bicep) - Complete app hosting stack with Front Door and App Gateway
- [examples/serverless-multitier.bicep](examples/serverless-multitier.bicep) - Serverless architecture with Function Apps, Event Hubs, and Storage
- [examples/advanced-features.bicep](examples/advanced-features.bicep) - Advanced scenarios with helper functions
- [examples/deployment-stack.bicep](examples/deployment-stack.bicep) - Deployment stacks pattern

### Documentation
- [docs/BICEP_BEST_PRACTICES.md](docs/BICEP_BEST_PRACTICES.md) - Comprehensive guide on maximizing Bicep's type system
- [README.md](README.md) - Complete project documentation with features and usage
