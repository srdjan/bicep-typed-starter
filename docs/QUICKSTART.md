# Quick Start Guide

Get up and running with bicep-typed-starter in 5 minutes!

## Prerequisites

```bash
# Install Azure CLI (if not already installed)
# Visit: https://docs.microsoft.com/cli/azure/install-azure-cli

# Install/upgrade Bicep CLI (requires 0.30.0+)
az bicep install
az bicep upgrade

# Verify version
az bicep version  # Should be 0.30.0 or higher

# Login to Azure
az login

# Set your subscription
az account set --subscription "Your-Subscription-Name"
```

## 5-Minute Deployment

### Step 1: Clone and Explore

```bash
git clone <repository-url>
cd bicep-typed-starter

# Explore the structure
ls -la
```

### Step 2: Create a Resource Group

```bash
# Create a resource group for development
az group create \
  --name rg-bicep-demo-dev \
  --location eastus
```

### Step 3: Deploy Your First Template

```bash
# Deploy the development environment
az deployment group create \
  --resource-group rg-bicep-demo-dev \
  --template-file main.bicep \
  --parameters env/dev.bicepparam
```

**That's it!** Your infrastructure is deploying. This creates:
- ✅ Virtual Network with 2 subnets
- ✅ App Service (Basic tier) with managed identity
- ✅ Security hardening (TLS 1.2, HTTPS only)

### Step 4: Verify Deployment

```bash
# Check deployment status
az deployment group show \
  --resource-group rg-bicep-demo-dev \
  --name main \
  --query properties.provisioningState

# Get outputs
az deployment group show \
  --resource-group rg-bicep-demo-dev \
  --name main \
  --query properties.outputs
```

## Advanced Examples

### Deploy Serverless Multi-Tier Application

```bash
# Create resource group
az group create \
  --name rg-serverless-prod \
  --location eastus

# Create Log Analytics workspace for monitoring
az monitor log-analytics workspace create \
  --resource-group rg-serverless-prod \
  --workspace-name law-serverless-prod \
  --location eastus

# Get workspace ID
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group rg-serverless-prod \
  --workspace-name law-serverless-prod \
  --query id -o tsv)

# Deploy serverless architecture
az deployment group create \
  --resource-group rg-serverless-prod \
  --template-file examples/serverless-multitier.bicep \
  --parameters environment=prod \
               projectName=myapp \
               location=eastus \
               logAnalyticsWorkspaceId="$WORKSPACE_ID"
```

This deploys:
- ✅ Azure Functions (API layer) with Premium plan
- ✅ App Service (Web UI layer) with auto-scaling
- ✅ Storage Account (Data layer) with versioning
- ✅ Application Insights for monitoring
- ✅ VNet integration for all components
- ✅ Comprehensive diagnostics

### Deploy with Deployment Stack

```bash
# Create/update deployment stack
az stack group create \
  --name myapp-stack \
  --resource-group rg-serverless-prod \
  --template-file examples/deployment-stack.bicep \
  --parameters environment=prod projectName=myapp \
  --deny-settings-mode denyDelete \
  --delete-resources \
  --yes

# View stack
az stack group show \
  --name myapp-stack \
  --resource-group rg-serverless-prod
```

## Explore Advanced Features

### See All Latest Bicep Features

```bash
# Deploy the advanced features showcase
az deployment group create \
  --resource-group rg-bicep-demo-dev \
  --template-file examples/advanced-features.bicep \
  --parameters environment=dev projectName=demo
```

This demonstrates:
- Import/Export with `@export()` decorator
- Spread operator (`...`) for object composition
- Lambda functions (`filter`, `map`, `reduce`, `groupBy`)
- User-defined functions
- Discriminated unions
- Nullability operators (`.?`, `??`, `!`)

### Validate Before Deploying

```bash
# Lint Bicep file
az bicep lint --file main.bicep

# Validate deployment (no actual deployment)
az deployment group validate \
  --resource-group rg-bicep-demo-dev \
  --template-file main.bicep \
  --parameters env/dev.bicepparam

# What-if analysis (preview changes)
az deployment group what-if \
  --resource-group rg-bicep-demo-dev \
  --template-file main.bicep \
  --parameters env/dev.bicepparam
```

## Customization Quick Tips

### Modify Environment Parameters

Edit `env/dev.bicepparam`:

```bicep
using 'main.bicep'

param env = 'dev'
param project = 'myproject'  // Change this
param tags = {
  env: 'dev'
  owner: 'your-team'         // Change this
  costCenter: 'YOUR-CC'      // Change this
}
param app = {
  name: 'myapp-dev'          // Change this
  tier: 'basic'
  location: 'eastus'
  ingress: {
    kind: 'publicIp'
    sku: 'Standard'
    dnsLabel: 'myapp-dev'    // Change this (must be globally unique)
  }
}
param vnet = {
  name: 'vnet-myapp-dev'
  location: 'eastus'
  addressSpaces: ['10.10.0.0/16']  // Adjust if needed
  subnets: [
    {name: 'app', prefix: '10.10.1.0/24'}
    {name: 'data', prefix: '10.10.2.0/24'}
  ]
}
```

### Use Helper Functions

```bicep
import {generateResourceName, buildTags, isProduction} from './lib/helpers.bicep'

// Generate consistent names
var appName = generateResourceName('app', 'myproject', 'prod', 'eastus')
// Result: 'app-myproject-prod-eastus'

// Build tags automatically
var tags = buildTags('prod', 'platform-team', 'myproject', 'PROD-001', null)

// Environment-aware logic
var enableHighAvailability = isProduction('prod')  // true
```

### Use Pre-built NSG Rules

```bicep
import {webTierRules, apiTierRules, databaseTierRules} from './lib/nsg-rules.bicep'

module nsg './modules/network/nsg.bicep' = {
  name: 'web-nsg'
  params: {
    input: {
      name: 'nsg-web'
      location: 'eastus'
      rules: webTierRules  // Pre-built rules for HTTPS/HTTP
      tags: tags
    }
  }
}
```

## Cleanup

```bash
# Delete resource group (removes all resources)
az group delete \
  --name rg-bicep-demo-dev \
  --yes --no-wait

# Delete deployment stack (handles resource lifecycle)
az stack group delete \
  --name myapp-stack \
  --resource-group rg-serverless-prod \
  --delete-all \
  --yes
```

## Next Steps

- 📖 Read [FEATURES.md](FEATURES.md) to learn about all advanced features
- 📖 Read [MIGRATION.md](MIGRATION.md) to upgrade existing Bicep code
- 📖 Study [examples/](../examples/) for real-world patterns
- 📖 Review [BICEP_BEST_PRACTICES.md](BICEP_BEST_PRACTICES.md) for in-depth type system guidance

## Troubleshooting

### Error: "userDefinedTypes feature not enabled"

```bash
# Check bicepconfig.json has:
{
  "experimentalFeaturesEnabled": {
    "userDefinedTypes": true
  }
}
```

### Error: "Cannot find import"

Make sure you're running Bicep CLI 0.25.3+ for imports/exports:

```bash
az bicep version
az bicep upgrade
```

### Error: "Spread operator not recognized"

Update to Bicep 0.27.1+ for spread operator support:

```bash
az bicep upgrade
```

## Support

- 🐛 Issues: [GitHub Issues](https://github.com/your-repo/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/your-repo/discussions)
- 📧 Contact: See README.md
