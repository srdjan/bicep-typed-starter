# Examples

This directory contains example Bicep templates demonstrating how to use the modules in this repository.

## Available Examples

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
