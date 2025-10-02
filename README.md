# Bicep Typed Starter

A production-ready Azure Infrastructure as Code starter template showcasing **Bicep's user-defined types** feature with discriminated unions, comprehensive type safety, and enterprise-grade patterns.

[![Bicep](https://img.shields.io/badge/Bicep-0.30+-blue.svg)](https://github.com/Azure/bicep)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

## 🚀 Features

### Type System
- ✅ **User-defined types** with experimental feature enabled
- ✅ **Discriminated unions** for polymorphic configurations (Ingress patterns)
- ✅ **Parameter validation** with `@minLength`, `@maxLength`, `@minValue`, `@maxValue`
- ✅ **Type safety** across module boundaries
- ✅ **IntelliSense support** with `@description` decorators

### Security & Compliance
- ✅ **System-assigned managed identity** for all App Services
- ✅ **TLS 1.2 minimum** enforced
- ✅ **FTPS disabled** by default
- ✅ **HTTP/2 enabled** for better performance
- ✅ **Private endpoint support** with full VNet integration
- ✅ **Resource locks** for production protection
- ✅ **PSRule validation** against Azure Well-Architected Framework

### Infrastructure Components
- ✅ **App Service** with configurable tiers (Basic, Standard, Premium)
- ✅ **Virtual Networks** with subnet configuration
- ✅ **Network Security Groups** with typed rule definitions
- ✅ **Diagnostic settings** with comprehensive logging (6 log categories + metrics)
- ✅ **Auto-scaling** with CPU-based rules
- ✅ **Entra ID integration** via Microsoft Graph extensions

### Developer Experience
- ✅ **Type-safe parameter files** (`.bicepparam`)
- ✅ **Comprehensive examples** for common scenarios
- ✅ **Modular architecture** for reusability
- ✅ **Complete documentation** with usage patterns

---

## 📋 Table of Contents

- [Quick Start](#-quick-start)
- [Architecture](#-architecture)
- [Type System](#-type-system)
- [Deployment Scenarios](#-deployment-scenarios)
- [Configuration Options](#-configuration-options)
- [Advanced Features](#-advanced-features)
- [Examples](#-examples)
- [Module Reference](#-module-reference)
- [Development](#-development)
- [Contributing](#-contributing)

---

## 🎯 Quick Start

### Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (2.50.0+)
- [Bicep CLI](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install) (0.30.0+)
- Azure subscription with appropriate permissions

### 1. Clone the Repository

```bash
git clone <repository-url>
cd bicep-typed-starter
```

### 2. Deploy Development Environment

```bash
# Create resource group
az group create --name dev-rg --location eastus

# Deploy infrastructure
az deployment group create \
  --resource-group dev-rg \
  --template-file main.bicep \
  --parameters env/dev.bicepparam
```

### 3. Verify Deployment

```bash
# Check deployment status
az deployment group show \
  --resource-group dev-rg \
  --name main \
  --query properties.provisioningState

# Get outputs
az deployment group show \
  --resource-group dev-rg \
  --name main \
  --query properties.outputs
```

---

## 🏗️ Architecture

### Project Structure

```
bicep-typed-starter/
├── main.bicep                    # Root orchestrator with type definitions
├── bicepconfig.json              # Enables userDefinedTypes feature
├── modules/
│   ├── app/
│   │   └── appservice.bicep      # App Service with auto-scaling, locks, private endpoints
│   ├── network/
│   │   ├── vnet.bicep            # Virtual Network with subnet configuration
│   │   └── nsg.bicep             # Network Security Group with typed rules
│   └── monitor/
│       └── diagnostics.bicep     # Comprehensive diagnostic settings
├── extensions/
│   └── graph/
│       ├── entra-group.bicep     # Entra ID group creation
│       └── entra-app-registration.bicep
├── env/
│   ├── dev.bicepparam            # Development environment
│   ├── prod.bicepparam           # Production with auto-scaling
│   └── privatelink.bicepparam    # Private Link configuration
├── examples/
│   ├── nsg-example.bicep         # NSG usage example
│   ├── complete-deployment.bicep # Full-featured deployment
│   └── README.md
├── policy/
│   ├── ps-rule.yaml              # PSRule configuration
│   └── Rules/
│       └── Naming.Rule.ps1       # Custom naming validation
└── docs/
    └── BICEP_BEST_PRACTICES.md
```

### Module Dependencies

```
main.bicep
  ├── modules/network/vnet.bicep
  └── modules/app/appservice.bicep
        └── modules/monitor/diagnostics.bicep
```

---

## 🎨 Type System

### Discriminated Unions

The project showcases Bicep's discriminated unions for type-safe polymorphic configurations:

```bicep
@discriminator('kind')
type Ingress =
  | { kind: 'publicIp', sku: 'Basic' | 'Standard', dnsLabel: string? }
  | { kind: 'privateLink', vnetId: string, subnetName: string }
  | { kind: 'appGateway', appGatewayId: string, listenerName: string }
```

**Benefits:**
- Type-safe access to variant-specific properties
- Compile-time validation of configuration
- IntelliSense support for each variant

### Type Definitions

#### Core Types

```bicep
type Env = 'dev' | 'test' | 'prod'
type Region = 'eastus' | 'westeurope' | 'westus'
type AppTier = 'basic' | 'standard' | 'premium'
```

#### Structural Types

```bicep
type TagPolicy = {
  env: 'dev' | 'test' | 'prod'
  owner: string
  costCenter: string?
}

type Diagnostics = {
  workspaceId: string?
  retentionDays: int?  // 1-365 days
}

type AutoScaleSettings = {
  minCapacity: int      // 1-30
  maxCapacity: int      // 1-30
  defaultCapacity: int  // 1-30
  scaleOutCpuThreshold: int?  // 1-100, default 70
  scaleInCpuThreshold: int?   // 1-100, default 30
}
```

### Parameter Validation

All parameters include validation decorators:

```bicep
type AppConfig = {
  @minLength(3)
  @maxLength(60)
  name: string

  location: Region
  tier: AppTier

  @minValue(1)
  @maxValue(30)
  capacity: int?

  ingress: Ingress
  diagnostics: Diagnostics?
  autoScale: AutoScaleSettings?
  enableDeleteLock: bool?
}
```

---

## 🚢 Deployment Scenarios

### Development Environment

**Characteristics:**
- Basic tier (cost-optimized)
- No auto-scaling
- No resource locks
- Public IP access
- Basic diagnostics

```bash
az deployment group create \
  --resource-group dev-rg \
  --template-file main.bicep \
  --parameters env/dev.bicepparam
```

### Production Environment (Public)

**Characteristics:**
- Premium tier (P1v3)
- Auto-scaling (3-10 instances)
- Resource locks enabled
- Public IP with DNS label
- 90-day log retention
- Comprehensive monitoring

```bash
az deployment group create \
  --resource-group prod-rg \
  --template-file main.bicep \
  --parameters env/prod.bicepparam
```

### Production Environment (Private Link)

**Characteristics:**
- Premium tier (P1v3)
- Private endpoint access only
- Public network access disabled
- VNet integration
- Resource locks enabled
- Full diagnostics

```bash
az deployment group create \
  --resource-group prod-rg \
  --template-file main.bicep \
  --parameters env/privatelink.bicepparam
```

---

## ⚙️ Configuration Options

### Application Configuration

#### Tiers

| Tier | SKU | Use Case | Auto-Scaling | AlwaysOn |
|------|-----|----------|--------------|----------|
| `basic` | B1 | Development, testing | ❌ | ❌ |
| `standard` | S1 | Staging, small production | ✅ | ✅ |
| `premium` | P1v3 | Production, high-performance | ✅ | ✅ |

#### Ingress Options

**Public IP Access:**
```bicep
ingress: {
  kind: 'publicIp'
  sku: 'Standard'
  dnsLabel: 'myapp-prod'  // Optional custom DNS
}
```

**Private Link Access:**
```bicep
ingress: {
  kind: 'privateLink'
  vnetId: '/subscriptions/.../virtualNetworks/vnet-hub'
  subnetName: 'private-endpoints'
}
```
Automatically configures:
- Private endpoint creation
- VNet integration
- Public access disabled
- All traffic routed through VNet

**Application Gateway:** (Structure defined for future use)
```bicep
ingress: {
  kind: 'appGateway'
  appGatewayId: '/subscriptions/.../applicationGateways/agw-prod'
  listenerName: 'myapp-listener'
}
```

### Network Configuration

**Virtual Network:**
```bicep
vnet: {
  name: 'vnet-myapp-prod'
  location: 'eastus'
  addressSpaces: ['10.0.0.0/16']
  subnets: [
    {
      name: 'app'
      prefix: '10.0.1.0/24'
      nsgId: '/subscriptions/.../networkSecurityGroups/nsg-app'  // Optional
    }
  ]
}
```

**Network Security Group:**
```bicep
// See examples/nsg-example.bicep for complete example
rules: [
  {
    name: 'AllowHttpsInbound'
    priority: 100
    direction: 'Inbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRange: '443'
    sourceAddressPrefix: 'Internet'
    destinationAddressPrefix: '*'
  }
]
```

### Monitoring Configuration

**Diagnostics:**
```bicep
diagnostics: {
  workspaceId: '/subscriptions/.../workspaces/prod-logs'
  retentionDays: 90  // 1-365 days
}
```

Collected data:
- HTTP logs
- Console logs
- Application logs
- Audit logs
- IPSec audit logs
- Platform logs
- All metrics

---

## 🔧 Advanced Features

### Auto-Scaling

Configure CPU-based horizontal auto-scaling:

```bicep
autoScale: {
  minCapacity: 3
  maxCapacity: 10
  defaultCapacity: 3
  scaleOutCpuThreshold: 75  // Scale out when CPU > 75%
  scaleInCpuThreshold: 25   // Scale in when CPU < 25%
}
```

**Behavior:**
- **Scale Out:** CPU > 75% for 5 minutes → add 1 instance (5 min cooldown)
- **Scale In:** CPU < 25% for 10 minutes → remove 1 instance (10 min cooldown)
- **Limits:** Stays within min/max capacity bounds

### Resource Protection

Enable delete locks for production resources:

```bicep
enableDeleteLock: true
```

Applies `CanNotDelete` locks to:
- App Service Plan
- App Service

**Note:** Locks must be manually removed before resource deletion.

### Managed Identity

All App Services automatically get a system-assigned managed identity:

```bicep
// Automatic - no configuration needed
identity: {
  type: 'SystemAssigned'
}
```

**Output:**
```bicep
output appPrincipalId string  // Use for RBAC assignments
```

**Usage:**
```bash
# Grant Key Vault access
az keyvault set-policy \
  --name my-keyvault \
  --object-id <principalId> \
  --secret-permissions get list
```

---

## 📚 Examples

### Basic Deployment

```bicep
param env = 'dev'
param project = 'myapp'
param tags = { env: 'dev', owner: 'platform-team' }

param app = {
  name: 'myapp-dev'
  tier: 'basic'
  location: 'eastus'
  ingress: { kind: 'publicIp', sku: 'Standard' }
}

param vnet = {
  name: 'vnet-myapp-dev'
  location: 'eastus'
  addressSpaces: ['10.10.0.0/16']
  subnets: [{ name: 'app', prefix: '10.10.1.0/24' }]
}
```

### Production with Auto-Scaling

See [env/prod.bicepparam](env/prod.bicepparam) for complete example.

### Private Link Deployment

See [env/privatelink.bicepparam](env/privatelink.bicepparam) for complete example.

### Complete Multi-Resource Deployment

See [examples/complete-deployment.bicep](examples/complete-deployment.bicep) for a full example including:
- Network Security Groups
- Virtual Network
- App Service with auto-scaling
- Diagnostics
- Resource locks

---

## 📖 Module Reference

### main.bicep

**Parameters:**
- `env`: Environment identifier (dev/test/prod)
- `project`: Project name for resource naming
- `tags`: Required tags policy
- `app`: Application configuration
- `vnet`: Virtual Network configuration

**Outputs:**
- `appId`: App Service resource ID
- `planId`: App Service Plan resource ID
- `appPrincipalId`: Managed identity principal ID
- `appHostname`: Default hostname
- `vnetId`: Virtual Network resource ID
- `vnetName`: Virtual Network name
- `subnetIds`: Array of subnet resource IDs

### modules/app/appservice.bicep

Deploys App Service with:
- App Service Plan with configurable tier/capacity
- App Service with security hardening
- Optional private endpoint (privateLink ingress)
- Optional auto-scaling rules
- Optional resource locks
- Optional diagnostics

### modules/network/vnet.bicep

Deploys Virtual Network with:
- Configurable address spaces
- Multiple subnets
- Optional NSG attachment per subnet

### modules/network/nsg.bicep

Deploys Network Security Group with:
- Typed security rules
- Priority validation (100-4096)
- All protocols supported

### modules/monitor/diagnostics.bicep

Configures diagnostic settings with:
- 6 log categories
- All metrics
- Configurable retention (1-365 days)
- Log Analytics workspace integration

---

## 🛠️ Development

### Prerequisites

```bash
# Install Bicep CLI
az bicep install

# Upgrade to latest
az bicep upgrade

# Verify version (0.30.0+)
az bicep version
```

### Build and Validate

```bash
# Build Bicep to ARM JSON
az bicep build --file main.bicep

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
```

### Linting and Policy Validation

```bash
# Bicep linting
az bicep lint --file main.bicep

# PSRule validation
pwsh -Command "Assert-PSRule -InputPath . -Module PSRule.Rules.Azure"
```

### Testing

```bash
# Test individual modules
az deployment group create \
  --resource-group test-rg \
  --template-file modules/network/nsg.bicep \
  --parameters @test-params.json

# Test complete deployment
az deployment group create \
  --resource-group test-rg \
  --template-file examples/complete-deployment.bicep \
  --parameters location=eastus environment=test projectName=test
```

---

## 🎓 Learning Resources

### Bicep Documentation
- [Bicep User-Defined Types](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/user-defined-data-types)
- [Discriminated Unions](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/data-types#discriminated-unions)
- [Bicep Best Practices](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/best-practices)

### Azure Documentation
- [App Service Security](https://learn.microsoft.com/en-us/azure/app-service/overview-security)
- [Private Endpoints](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview)
- [Auto-scaling in Azure](https://learn.microsoft.com/en-us/azure/azure-monitor/autoscale/autoscale-overview)

### Project Documentation
- [CLAUDE.md](CLAUDE.md) - Development guide for Claude Code
- [IMPROVEMENTS.md](IMPROVEMENTS.md) - Complete improvement history
- [examples/README.md](examples/README.md) - Example usage patterns
- [docs/BICEP_BEST_PRACTICES.md](docs/BICEP_BEST_PRACTICES.md) - Best practices guide

---

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. **Fork the repository**
2. **Create a feature branch:** `git checkout -b feature/amazing-feature`
3. **Make your changes** following the existing patterns:
   - Add `@description` decorators to all parameters
   - Include parameter validation decorators
   - Update type definitions in both main and modules
   - Add examples for new features
4. **Test your changes:**
   ```bash
   az bicep build --file main.bicep
   az deployment group validate --resource-group test-rg --template-file main.bicep
   ```
5. **Update documentation** (README.md, CLAUDE.md)
6. **Commit your changes:** `git commit -m 'Add amazing feature'`
7. **Push to the branch:** `git push origin feature/amazing-feature`
8. **Open a Pull Request**

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- [Azure Bicep Team](https://github.com/Azure/bicep) for the amazing IaC language
- [PSRule for Azure](https://github.com/Azure/PSRule.Rules.Azure) for policy validation
- Community contributors and feedback

---

## 📧 Support

- **Issues:** [GitHub Issues](https://github.com/your-repo/issues)
- **Discussions:** [GitHub Discussions](https://github.com/your-repo/discussions)
- **Documentation:** [CLAUDE.md](CLAUDE.md)

---

## 🗺️ Roadmap

### Current Version (v1.0)
- ✅ User-defined types with discriminated unions
- ✅ Complete type safety
- ✅ Security hardening
- ✅ Auto-scaling support
- ✅ Private Link integration
- ✅ Resource locks
- ✅ Comprehensive examples

### Future Enhancements
- 🔜 Application Gateway integration (structure defined)
- 🔜 Deployment slots support
- 🔜 Custom domain configuration
- 🔜 Key Vault integration for SSL certificates
- 🔜 Multi-region deployment patterns
- 🔜 Container Apps module
- 🔜 API Management integration

---

**Made with ❤️ using Azure Bicep**

---

## Quick Reference Card

```bash
# Development
az deployment group create --resource-group dev-rg --template-file main.bicep --parameters env/dev.bicepparam

# Production (Public)
az deployment group create --resource-group prod-rg --template-file main.bicep --parameters env/prod.bicepparam

# Production (Private Link)
az deployment group create --resource-group prod-rg --template-file main.bicep --parameters env/privatelink.bicepparam

# Validate
az deployment group validate --resource-group <rg> --template-file main.bicep --parameters <params>

# What-if
az deployment group what-if --resource-group <rg> --template-file main.bicep --parameters <params>

# Build
az bicep build --file main.bicep

# Lint
az bicep lint --file main.bicep
```
