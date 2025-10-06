# Examples

This directory contains example Bicep templates demonstrating how to use the modules and latest Bicep features.

## Available Examples

### [advanced-features.bicep](advanced-features.bicep) ⭐ NEW
**Showcases all latest Bicep features (2024-2025)**

Demonstrates:
- ✅ Import/Export with `@export()` decorator
- ✅ Spread operator (`...`) for object/array composition
- ✅ Lambda functions (`filter`, `map`, `reduce`, `groupBy`, `sort`)
- ✅ User-defined functions
- ✅ Discriminated unions
- ✅ Nullability operators (`.?`, `??`, `!`)

**Usage:**
```bash
az deployment group create \
  --resource-group <rg-name> \
  --template-file examples/advanced-features.bicep \
  --parameters environment=dev projectName=demo
```

**What you'll learn:**
- How to filter and transform data with lambda functions
- How to build reusable helper functions
- How to use pre-built NSG rule sets
- How to compose complex configurations safely

---

### [serverless-multitier.bicep](serverless-multitier.bicep) ⭐ NEW
**Complete serverless architecture**

Deploys a production-ready 3-tier serverless application:
- 🌐 **Web Layer**: App Service with auto-scaling
- ⚡ **API Layer**: Azure Functions (Node.js 20) with Premium plan
- 💾 **Data Layer**: Storage Account with versioning
- 📊 **Monitoring**: Application Insights with centralized logging
- 🔒 **Security**: VNet integration, private endpoints, NSGs

**Usage:**
```bash
# Create Log Analytics workspace first
az monitor log-analytics workspace create \
  --resource-group <rg-name> \
  --workspace-name law-demo \
  --location eastus

# Get workspace ID
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group <rg-name> \
  --workspace-name law-demo \
  --query id -o tsv)

# Deploy serverless architecture
az deployment group create \
  --resource-group <rg-name> \
  --template-file examples/serverless-multitier.bicep \
  --parameters environment=prod \
               projectName=myapp \
               logAnalyticsWorkspaceId="$WORKSPACE_ID"
```

**Features:**
- Production-ready configuration
- High availability with auto-scaling
- Comprehensive monitoring and diagnostics
- Network isolation with VNet integration
- Managed identities for secure access
- Environment-aware defaults

---

### [deployment-stack.bicep](deployment-stack.bicep) ⭐ NEW
**Azure Deployment Stacks demonstration**

Shows lifecycle management with deployment stacks (GA feature):
- Unified resource management
- Delete protection (`denyDelete`, `denyWriteAndDelete`)
- Automatic cleanup of removed resources
- Atomic updates

**Usage:**
```bash
# Create deployment stack
az stack group create \
  --name myapp-stack \
  --resource-group <rg-name> \
  --template-file examples/deployment-stack.bicep \
  --parameters environment=prod projectName=myapp \
  --deny-settings-mode denyDelete \
  --delete-resources \
  --yes

# View stack
az stack group show \
  --name myapp-stack \
  --resource-group <rg-name>

# Delete stack (removes all resources)
az stack group delete \
  --name myapp-stack \
  --resource-group <rg-name> \
  --delete-all \
  --yes
```

---

### [nsg-example.bicep](nsg-example.bicep)
Demonstrates how to create a Network Security Group with common web application rules:
- Allow HTTPS (port 443)
- Allow HTTP (port 80)
- Deny all other inbound traffic

**Usage:**
```bash
az deployment group create \
  --resource-group <rg-name> \
  --template-file examples/nsg-example.bicep \
  --parameters location=eastus environment=dev
```

---

### [complete-deployment.bicep](complete-deployment.bicep)
Full-featured deployment showing all capabilities:
- Network Security Group with custom rules
- Virtual Network with NSG-protected subnets
- App Service with:
  - Premium tier (P1v3)
  - System-assigned managed identity
  - Auto-scaling (3-10 instances based on CPU)
  - Comprehensive diagnostics
  - Delete locks enabled
  - Security hardening (TLS 1.2, FTPS disabled, HTTP/2)

**Usage:**
```bash
az deployment group create \
  --resource-group <rg-name> \
  --template-file examples/complete-deployment.bicep \
  --parameters location=eastus environment=prod projectName=myapp
```

### [app-hosting-stack.bicep](app-hosting-stack.bicep) ⭐ NEW
Full stack aligned with the modern Azure Web Apps reference architecture:
- Azure Front Door Standard/Premium routing global traffic
- Application Gateway WAF v2 terminating TLS and forwarding to API Management
- API Management (Developer/Premium tiers) fronting a Function App backend
- Event Hubs namespace for async messaging
- PostgreSQL Flexible Server with delegated subnet for data persistence

**Usage:**
```bash
az deployment group create \
  --resource-group <rg-name> \
  --template-file examples/app-hosting-stack.bicep \
  --parameters \
      projectName=myapp \
      tags="{ env: 'dev', owner: 'platform-team', costCenter: 'ENG-001' }" \
      functionStorageAccountName=<existing-storage-account> \
      postgresAdminPassword=<S3cureP@ssw0rd>
```

> Requires an existing storage account for the Function App content share. All other services are provisioned and connected automatically.

## Parameter Files

See the [env/](../env/) directory for complete parameter file examples:

- **[dev.bicepparam](../env/dev.bicepparam)** - Basic development environment
- **[prod.bicepparam](../env/prod.bicepparam)** - Production with auto-scaling and locks
- **[privatelink.bicepparam](../env/privatelink.bicepparam)** - Private Link configuration

## Common Patterns

### Public Internet Access
```bicep
ingress: {
  kind: 'publicIp'
  sku: 'Standard'
  dnsLabel: 'myapp-prod'
}
```

### Private Link Access
```bicep
ingress: {
  kind: 'privateLink'
  vnetId: '/subscriptions/.../virtualNetworks/vnet-hub'
  subnetName: 'private-endpoints'
}
```

### Auto-Scaling Configuration
```bicep
autoScale: {
  minCapacity: 2
  maxCapacity: 10
  defaultCapacity: 3
  scaleOutCpuThreshold: 75
  scaleInCpuThreshold: 25
}
```

### Enabling Resource Locks
```bicep
enableDeleteLock: true
```
