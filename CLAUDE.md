# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a **typed Bicep starter template** demonstrating Azure Infrastructure as Code with strong typing using Bicep's user-defined types feature. The project showcases discriminated unions, type safety, modular architecture, and Microsoft Graph extensions for Entra ID resources.

## Prerequisites

- Azure CLI (2.50.0+) with Bicep CLI (0.30.0+) installed
- `bicepconfig.json` enables experimental `userDefinedTypes` feature
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
main.bicep              # Root orchestrator with type definitions and module composition
├── modules/
│   ├── network/        # Network resources (VNets, NSGs, subnets)
│   │   ├── vnet.bicep  # Virtual Network with subnet configuration
│   │   └── nsg.bicep   # Network Security Groups with rule definitions
│   ├── app/           # App Service Plan and Web App with managed identity
│   └── monitor/       # Diagnostic settings with comprehensive logging
├── extensions/
│   └── graph/         # Microsoft Graph resources (Entra ID groups/apps) - tenant scope
├── env/               # Environment-specific .bicepparam files
├── examples/          # Usage examples for modules
└── policy/            # PSRule validation rules
```

**Key architectural decisions**:
1. **Types defined at root** (`main.bicep`): Shared types like `Ingress`, `AppConfig`, `Region` are declared in the main file and re-declared in modules as needed (Bicep doesn't support type imports)
2. **Modules are pure**: Each module declares its own parameter types and exposes typed outputs
3. **Conditional deployment**: Uses `if` expressions for optional diagnostics: `module diag '...' = if (app.diagnostics!=null)`
4. **Tag composition**: Common tags merged with module-specific tags via `union(tags, {...})`

### Type Patterns in Use

1. **Discriminated unions** (`Ingress`): Pattern matching via `kind` field enables conditional logic in modules
   - `publicIp`: Public internet access with optional DNS label
   - `privateLink`: Private endpoint with VNet integration (fully implemented)
   - `appGateway`: Application Gateway integration (structure defined)
2. **Optional properties** (`diagnostics?`, `costCenter?`, `capacity?`, `autoScale?`): Use `?` suffix for nullable fields
3. **Nested structural types**: `AppConfig` embeds `Ingress`, `Diagnostics`, `TagPolicy`, and `AutoScaleSettings`
4. **Parameter validation**: `@minLength`, `@maxLength`, `@minValue`, `@maxValue` decorators enforce constraints
5. **Tier mapping**: SKU map object converts abstract tiers to Azure SKU names and tier strings
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
1. Define types in `main.bicep` if shared across modules
2. Re-declare needed types in individual modules (no cross-file type imports)
3. Use discriminated unions for polymorphic resources (follow `Ingress` pattern)
4. Add `@description`, `@minLength`, `@maxLength` decorators for all parameters

### Adding New Modules
1. Create module in `modules/<category>/<name>.bicep`
2. Define input parameter types at module level with validation decorators
3. Add `@description` to all parameters and outputs
4. Export outputs with explicit types and descriptions
5. Reference in `main.bicep` with typed parameters
6. See `examples/` directory for usage patterns

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
- **Missing discriminator**: Ensure union variants have unique `kind` values
- **Type redeclaration mismatch**: Types must match exactly between main and modules (including decorators). Bicep doesn't support type imports, so types are re-declared in each module
- **Null handling**: Use `!` non-null assertion operator when Bicep can't infer (`diag!.workspaceId`)
- **Capacity limits**: App Service capacity is capped at 30 instances via `@maxValue(30)`
- **Union type constraints**: Union members must share a single underlying primitive (all strings or all ints). Mixed unions like `'a' | 1` are invalid

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

- [main.bicep](main.bicep) - Root template with type definitions and module orchestration
- [bicepconfig.json](bicepconfig.json) - Enables `userDefinedTypes` experimental feature
- [env/dev.bicepparam](env/dev.bicepparam) - Development environment parameters
- [env/prod.bicepparam](env/prod.bicepparam) - Production environment with auto-scaling and locks
- [env/privatelink.bicepparam](env/privatelink.bicepparam) - Private Link configuration example
- [modules/app/appservice.bicep](modules/app/appservice.bicep) - App Service with managed identity, security hardening, auto-scaling, private endpoints
- [modules/network/vnet.bicep](modules/network/vnet.bicep) - Virtual Network with configurable location
- [modules/network/nsg.bicep](modules/network/nsg.bicep) - Network Security Group with typed rules
- [modules/monitor/diagnostics.bicep](modules/monitor/diagnostics.bicep) - Comprehensive diagnostic settings for App Service
- [extensions/graph/entra-group.bicep](extensions/graph/entra-group.bicep) - Microsoft Graph extension for Entra ID groups
- [examples/nsg-example.bicep](examples/nsg-example.bicep) - Example NSG configuration with web app rules
- [examples/complete-deployment.bicep](examples/complete-deployment.bicep) - Full-featured deployment with NSG, VNet, App Service, auto-scaling, and locks
- [docs/BICEP_BEST_PRACTICES.md](docs/BICEP_BEST_PRACTICES.md) - Comprehensive guide on maximizing Bicep's type system
