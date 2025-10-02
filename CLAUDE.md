# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a **typed Bicep starter template** demonstrating Azure Infrastructure as Code with strong typing using Bicep's user-defined types feature. The project showcases discriminated unions, type safety, modular architecture, and Microsoft Graph extensions for Entra ID resources.

## Prerequisites

- Azure CLI with Bicep CLI installed
- `bicepconfig.json` enables experimental `userDefinedTypes` feature
- PSRule for Azure (for policy validation)

## Common Commands

### Bicep Operations
```bash
# Build/compile Bicep to ARM JSON
az bicep build --file main.bicep

# Deploy using parameter file
az deployment group create \
  --resource-group <rg-name> \
  --template-file main.bicep \
  --parameters env/dev.bicepparam

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
│   ├── network/        # Network resources (VNets, subnets)
│   ├── app/           # App Service Plan and Web App
│   └── monitor/       # Diagnostic settings
├── extensions/
│   └── graph/         # Microsoft Graph resources (Entra ID groups/apps) - tenant scope
├── env/               # Environment-specific .bicepparam files
└── policy/            # PSRule validation rules
```

**Key architectural decisions**:
1. **Types defined at root** (`main.bicep`): Shared types like `Ingress`, `AppConfig`, `Region` are declared in the main file and re-declared in modules as needed (Bicep doesn't support type imports)
2. **Modules are pure**: Each module declares its own parameter types and exposes typed outputs
3. **Conditional deployment**: Uses `if` expressions for optional diagnostics: `module diag '...' = if (app.diagnostics!=null)`
4. **Tag composition**: Common tags merged with module-specific tags via `union(tags, {...})`

### Type Patterns in Use

1. **Discriminated unions** (`Ingress`): Pattern matching via `kind` field enables conditional logic in modules
2. **Optional properties** (`diagnostics?`, `costCenter?`): Use `?` suffix for nullable fields
3. **Nested structural types**: `AppConfig` embeds `Ingress`, `Diagnostics`, and `TagPolicy`
4. **Tier mapping**: Convert abstract tier (`basic`|`standard`|`premium`) to Azure SKU names via ternary expressions

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

### Adding New Modules
1. Create module in `modules/<category>/<name>.bicep`
2. Define input parameter types at module level
3. Export outputs with explicit types
4. Reference in `main.bicep` with typed parameters

### Validation Strategy
- **Compile-time**: Bicep type system enforces parameter contracts
- **Pre-deployment**: `az deployment group validate` checks ARM API compliance
- **Policy**: PSRule validates against Azure Well-Architected Framework (see `policy/Rules/`)

### Common Type Errors
- **Missing discriminator**: Ensure union variants have unique `kind` values
- **Type redeclaration mismatch**: Types must match exactly between main and modules
- **Null handling**: Use `!` non-null assertion operator when Bicep can't infer (`diag!.workspaceId`)

## Key Files

- [main.bicep](main.bicep) - Root template with type definitions and module orchestration
- [bicepconfig.json](bicepconfig.json) - Enables `userDefinedTypes` experimental feature
- [env/dev.bicepparam](env/dev.bicepparam) - Development environment parameters
- [modules/app/appservice.bicep](modules/app/appservice.bicep) - Shows discriminated union usage for ingress patterns
- [extensions/graph/entra-group.bicep](extensions/graph/entra-group.bicep) - Microsoft Graph extension example
