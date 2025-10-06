# Advanced Bicep Features Showcase

This document provides a visual catalog of all cutting-edge Bicep features (2024-2025) demonstrated in this repository.

## Table of Contents

- [Import/Export System](#importexport-system)
- [Spread Operator](#spread-operator)
- [Lambda Functions](#lambda-functions)
- [User-Defined Functions](#user-defined-functions)
- [Discriminated Unions](#discriminated-unions)
- [Nullability Operators](#nullability-operators)
- [Deployment Stacks](#deployment-stacks)
- [Type-Safe Parameters](#type-safe-parameters)

---

## Import/Export System

**Status:** GA (Bicep 0.25.3+)
**Files:** `types/common.bicep`, `lib/helpers.bicep`, `main.bicep`

### What It Does

Share types, variables, and functions across Bicep files using `@export()` decorator and `import` statements.

### Before (Without Imports)

```bicep
// main.bicep - Type definitions duplicated
type Env = 'dev' | 'test' | 'prod'
type Region = 'eastus' | 'westeurope'

// module.bicep - Same types duplicated again!
type Env = 'dev' | 'test' | 'prod'
type Region = 'eastus' | 'westeurope'
```

### After (With Imports)

```bicep
// types/common.bicep - Single source of truth
@export()
type Env = 'dev' | 'test' | 'prod'

@export()
type Region = 'eastus' | 'westeurope'

// main.bicep - Import types
import {Env, Region} from './types/common.bicep'

// module.bicep - Same imports
import {Env, Region} from '../types/common.bicep'
```

### Advanced Patterns

```bicep
// Specific imports
import {Env, Region} from './types/common.bicep'

// Aliased imports
import {Region as AzureRegion} from './types/common.bicep'

// Wildcard imports
import * as types from './types/common.bicep'
```

### Benefits

✅ **DRY Principle** - Define once, use everywhere
✅ **Consistency** - No type drift across modules
✅ **Maintainability** - Update types in one place
✅ **IntelliSense** - Full IDE support

---

## Spread Operator

**Status:** GA (Bicep 0.27.1+)
**Files:** `main.bicep`, `examples/advanced-features.bicep`

### What It Does

Expand objects and arrays inline using `...` syntax, similar to JavaScript/TypeScript.

### Object Spreading

#### Before (union function)

```bicep
var baseTags = {env: 'prod', owner: 'team'}
var extraTags = {costCenter: 'CC-001'}
var allTags = union(baseTags, extraTags)
```

#### After (spread operator)

```bicep
var baseTags = {env: 'prod', owner: 'team'}
var extraTags = {costCenter: 'CC-001'}
var allTags = {
  ...baseTags
  ...extraTags
  deployedBy: 'bicep'  // Additional properties
}
```

### Array Spreading

```bicep
var baseSettings = [
  {name: 'ENV', value: 'prod'}
]

var prodSettings = [
  {name: 'DEBUG', value: 'false'}
]

// Combine arrays
var allSettings = [
  ...baseSettings
  ...prodSettings
  {name: 'REGION', value: 'eastus'}
]
```

### Conditional Spreading

```bicep
var config = {
  name: 'app'
  tier: 'premium'
  ...((environment == 'prod') ? {highAvailability: true} : {})
  ...(diagnostics != null ? {monitoring: diagnostics} : {})
}
```

### Benefits

✅ **Cleaner Syntax** - More readable than `union()`
✅ **Conditional Properties** - Easy to add/remove props
✅ **Composition** - Build complex objects incrementally

---

## Lambda Functions

**Status:** GA (Bicep 0.10+, enhanced in 2024)
**Files:** `lib/transformations.bicep`, `examples/advanced-features.bicep`

### Available Functions

| Function | Purpose | Example |
|----------|---------|---------|
| `filter()` | Select elements matching criteria | `filter(items, i => i.enabled)` |
| `map()` | Transform each element | `map(items, i => i.name)` |
| `reduce()` | Aggregate values | `reduce(nums, 0, (acc, n) => acc + n)` |
| `sort()` | Order elements | `sort(items, (a, b) => a.priority < b.priority)` |
| `groupBy()` | Group by property | `groupBy(items, i => i.type)` |
| `toObject()` | Convert array to object | `toObject(arr, i => i.key, i => i.value)` |

### Examples

#### Filter Subnets by Pattern

```bicep
var allSubnets = [
  {name: 'app-web', prefix: '10.0.1.0/24'}
  {name: 'app-api', prefix: '10.0.2.0/24'}
  {name: 'data-sql', prefix: '10.0.3.0/24'}
]

// Get only app-tier subnets
var appSubnets = filter(allSubnets, subnet => startsWith(subnet.name, 'app'))
// Result: [{name: 'app-web', ...}, {name: 'app-api', ...}]
```

#### Map Subnet Names to IDs

```bicep
var subnetIds = map(
  subnets,
  subnet => resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnet.name)
)
```

#### Reduce to Calculate Total

```bicep
var cidrBlocks = ['10.0.1.0/24', '10.0.2.0/24', '10.0.3.0/24']
var totalIps = reduce(
  map(cidrBlocks, cidr => pow(2, 32 - int(last(split(cidr, '/'))))),
  0,
  (acc, count) => acc + count
)
// Result: 768 (256 + 256 + 256)
```

#### Sort NSG Rules by Priority

```bicep
import {sortRulesByPriority} from './lib/transformations.bicep'

var unsortedRules = [...] // Mixed priority rules
var sortedRules = sortRulesByPriority(unsortedRules)
```

#### Group Resources by Type

```bicep
var resources = [
  {name: 'web-1', type: 'webapp'}
  {name: 'api-1', type: 'function'}
  {name: 'web-2', type: 'webapp'}
]

var grouped = groupBy(resources, r => r.type)
// Result: {webapp: [{...}, {...}], function: [{...}]}
```

### Benefits

✅ **Functional Programming** - Transform data declaratively
✅ **Type-Safe** - Full IntelliSense support
✅ **Composable** - Chain operations together

---

## User-Defined Functions

**Status:** GA (Bicep 0.24+, enhanced with imports in 0.31+)
**Files:** `lib/helpers.bicep`

### What It Does

Create reusable functions with `func` keyword and share them using `@export()`.

### Examples

#### Resource Naming Convention

```bicep
@export()
func generateResourceName(resourceType string, project string, env string, region string) string =>
  toLower('${resourceType}-${project}-${env}-${region}')

// Usage:
var appName = generateResourceName('app', 'myproject', 'prod', 'eastus')
// Result: 'app-myproject-prod-eastus'
```

#### Tag Builder

```bicep
@export()
func buildTags(env string, owner string, project string, costCenter string?) object => {
  env: env
  owner: owner
  project: project
  ...((costCenter != null) ? {costCenter: costCenter} : {})
}

// Usage:
var tags = buildTags('prod', 'platform-team', 'myapp', 'CC-001')
```

#### SKU Mapping

```bicep
@export()
func getSkuForTier(tier string) object =>
  tier == 'basic'
    ? {name: 'B1', tier: 'Basic'}
    : tier == 'standard'
      ? {name: 'S1', tier: 'Standard'}
      : {name: 'P1v3', tier: 'PremiumV3'}
```

#### Environment Detection

```bicep
@export()
func isProduction(env string) bool => env == 'prod'

@export()
func getRetentionDaysForEnv(env string) int =>
  env == 'prod' ? 90 : env == 'test' ? 30 : 7
```

### Benefits

✅ **Reusability** - Write once, use everywhere
✅ **Testability** - Pure functions, predictable results
✅ **Documentation** - Self-documenting code

---

## Discriminated Unions

**Status:** GA (Bicep 0.20+)
**Files:** `types/common.bicep`, `modules/storage/storageaccount.bicep`

### What It Does

Create type-safe variants using `@discriminator` decorator, similar to TypeScript discriminated unions.

### Example: Ingress Configuration

```bicep
@discriminator('kind')
type Ingress =
  | {kind: 'publicIp', sku: 'Basic' | 'Standard', dnsLabel: string?}
  | {kind: 'privateLink', vnetId: string, subnetName: string}
  | {kind: 'appGateway', appGatewayId: string, listenerName: string}

param ingress Ingress

// Type-safe property access
var isPublic = ingress.kind == 'publicIp'
var dnsLabel = isPublic ? ingress.dnsLabel : null  // Only accessible when kind='publicIp'
```

### Example: Storage Kind

```bicep
@discriminator('kind')
type StorageKind =
  | {kind: 'BlobStorage', accessTier: 'Hot' | 'Cool'}
  | {kind: 'StorageV2', accessTier: 'Hot' | 'Cool'}
  | {kind: 'FileStorage'}
  | {kind: 'BlockBlobStorage'}

// Type narrowing
var accessTier = storage.kind == 'BlobStorage' || storage.kind == 'StorageV2'
  ? storage.accessTier
  : null
```

### Example: Hosting Plan

```bicep
@discriminator('tier')
type HostingPlan =
  | {tier: 'consumption'}
  | {tier: 'elastic', maximumElasticWorkerCount: int}
  | {tier: 'premium', sku: 'EP1' | 'EP2' | 'EP3', workerCount: int?}
```

### Benefits

✅ **Type Safety** - Illegal combinations prevented at compile time
✅ **IntelliSense** - Only valid properties shown for each variant
✅ **Maintainability** - Changes to one variant don't affect others

---

## Nullability Operators

**Status:** GA (Bicep 0.19+)
**Files:** All modules

### Operators

| Operator | Name | Purpose | Example |
|----------|------|---------|---------|
| `.?` | Safe dereference | Access property that might be null | `config.?workspaceId` |
| `??` | Coalesce | Provide default for null value | `retentionDays ?? 30` |
| `!` | Null-forgiving | Assert value is non-null | `workspaceId!` |

### Examples

#### Safe Navigation

```bicep
param diagnostics {workspaceId: string?, retentionDays: int?}?

// Safe access - returns null if diagnostics is null
var workspaceId = diagnostics.?workspaceId

// Chain safely
var retention = diagnostics.?retentionDays ?? 30
```

#### Coalescing with Defaults

```bicep
param capacity int?
param environment string

// Provide environment-based defaults
var actualCapacity = capacity ?? (environment == 'prod' ? 3 : 1)
```

#### Null Assertion

```bicep
resource diagSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (diag != null) {
  properties: {
    workspaceId: diag!.workspaceId  // Assert diag is not null here
  }
}
```

### Benefits

✅ **Safety** - Avoid null reference errors
✅ **Defaults** - Easy fallback values
✅ **Explicit** - Clear intent in code

---

## Deployment Stacks

**Status:** GA (2024)
**Files:** `examples/deployment-stack.bicep`

### What It Does

Manage collections of Azure resources as a single unit with lifecycle management and protection.

### Key Features

1. **Unified Management** - Update/delete all resources atomically
2. **Deny Settings** - Protect from accidental changes
   - `denyDelete` - Prevent deletion
   - `denyWriteAndDelete` - Read-only resources
3. **Cleanup Behaviors** - Control what happens to removed resources
   - `detach` - Leave resources but remove from stack
   - `delete` - Remove resources from Azure

### Deployment

```bash
# Create stack with delete protection
az stack group create \
  --name myapp-stack \
  --resource-group rg-prod \
  --template-file examples/deployment-stack.bicep \
  --parameters environment=prod projectName=myapp \
  --deny-settings-mode denyDelete \
  --delete-resources \
  --yes

# View stack
az stack group show --name myapp-stack --resource-group rg-prod

# Delete stack and all resources
az stack group delete \
  --name myapp-stack \
  --resource-group rg-prod \
  --delete-all \
  --yes
```

### Benefits

✅ **Lifecycle Management** - Resources managed as a unit
✅ **Protection** - Prevent accidental changes/deletions
✅ **Cleanup** - Automatic resource removal when no longer needed

---

## Type-Safe Parameters

**Status:** GA
**Files:** All `.bicepparam` files

### Parameter Files with Type Safety

```bicep
// dev.bicepparam
using 'main.bicep'  // Inherits all type definitions

param env = 'dev'  // Type-checked against Env type
param project = 'myapp'

param app = {  // Type-checked against AppConfig type
  name: 'myapp-dev'
  tier: 'basic'  // IntelliSense shows: 'basic' | 'standard' | 'premium'
  location: 'eastus'  // IntelliSense shows: 'eastus' | 'westeurope' | 'westus'
  ingress: {
    kind: 'publicIp'  // IntelliSense shows union variants
    sku: 'Standard'
    dnsLabel: 'myapp-dev'
  }
}
```

### Benefits

✅ **IntelliSense** - Full autocomplete in VS Code
✅ **Validation** - Errors before deployment
✅ **Documentation** - Types serve as docs

---

## Comparison: Old vs New

### Tag Merging

| Feature | Old Way | New Way |
|---------|---------|---------|
| **Function** | `union(baseTags, extraTags)` | `{...baseTags, ...extraTags}` |
| **Readability** | Medium | High |
| **Flexibility** | Limited | High (conditional spreading) |

### Code Reuse

| Feature | Old Way | New Way |
|---------|---------|---------|
| **Types** | Copy-paste across files | `@export()` + `import` |
| **Functions** | Not available | `@export()` user-defined functions |
| **Variables** | Not available | `@export()` compile-time constants |

### Data Transformation

| Feature | Old Way | New Way |
|---------|---------|---------|
| **Filtering** | Manual loops or conditions | `filter()` lambda |
| **Mapping** | Not available | `map()` lambda |
| **Aggregation** | Complex expressions | `reduce()` lambda |

---

## Feature Adoption Checklist

- [ ] Replace `union()` with spread operator (`...`)
- [ ] Create `types/common.bicep` with `@export()` types
- [ ] Create `lib/helpers.bicep` with reusable functions
- [ ] Use discriminated unions for polymorphic config
- [ ] Apply nullability operators (`.?`, `??`, `!`)
- [ ] Use lambda functions for data transformation
- [ ] Leverage deployment stacks for lifecycle management
- [ ] Add `.bicepparam` files for type-safe parameters

---

## Resources

- [Bicep Import/Export](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/bicep-import)
- [Spread Operator](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/operator-spread)
- [Lambda Functions](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/bicep-functions-lambda)
- [User-Defined Functions](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/user-defined-functions)
- [Discriminated Unions](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/data-types#discriminated-unions)
- [Deployment Stacks](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deployment-stacks)
