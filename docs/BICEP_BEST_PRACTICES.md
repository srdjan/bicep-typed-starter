# Bicep Best Practices Guide: Squeezing Every Drop of Value Out of the Type System

---

# 1) Treat types as your domain model

## 1.1 User-defined types (UDTs) for reuse & clarity

Create named types for any object/shape used more than once (environment config, tagging policy, SKU selectors, etc.). UDTs compile to plain ARM, but give you IDE IntelliSense, validation, and clean module contracts.

```bicep
// types.bicep
type TagMap = {
  'env': 'dev' | 'test' | 'prod'
  'owner': string
  'costCenter'?: string
}

type StorageSku = 'Standard_LRS' | 'Standard_GRS' | 'Premium_LRS'

type StorageConfig = {
  name: string
  sku: StorageSku
  tags: TagMap
}
```

Use them everywhere:

```bicep
param cfg StorageConfig

resource sa 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: cfg.name
  location: resourceGroup().location
  sku: { name: cfg.sku }
  kind: 'StorageV2'
  tags: cfg.tags
}
```

Why it helps:

* Centralized changes (rename a tag once, fix everywhere).
* “Explainable” contracts at module boundaries.
  Docs: user-defined types. ([Microsoft Learn][1])

---

# 2) Encode constraints in types, not prose

## 2.1 Literal unions instead of @allowed

`@allowed` only works on `param`. Prefer **literal unions** inside UDTs too, so constraints travel with the shape.

```bicep
// Good: the enum is part of the type, reusable across param/var/output.
type Region = 'eastus' | 'westus' | 'westeurope'
type Tier   = 'basic' | 'standard' | 'premium'
```

Docs: unions + allowed guidance. ([Microsoft Learn][2])

## 2.2 Tuples for fixed-arity lists

When an array must be “exactly N items and typed”, use tuples.

```bicep
type CidrPair = [ string, string ] // [vnetCidr, subnetCidr]
param cidrs CidrPair
```

(See **Data types** for tuples/arrays.) ([Microsoft Learn][2])

## 2.3 Nullable everywhere with `?`, not hacks

Make things optional with `?` (no empty-string sentinels). Pair with null-operators (next section).

```bicep
type Diagnostics = {
  workspaceId?: string
  retentionDays?: int
}

param diag Diagnostics?  // may be null
```

Docs: **Nullable types**. ([Microsoft Learn][2])

---

# 3) Nullability operators: model “maybe” safely

| Operator                | What it does                                    | Typical use                                        |
| ----------------------- | ----------------------------------------------- | -------------------------------------------------- |
| `.?` (safe-dereference) | Returns `null` if base is `null`/missing        | Chain optional props from params or module outputs |
| `??` (coalesce)         | Fallback when left is `null`                    | Provide defaults for optional fields               |
| `!` (null-forgiving)    | Assert non-null to silence `null \| T` warnings | When you *know* a value is non-null post-check     |

Examples:

```bicep
// safe navigation to avoid runtime errors:
var wsId = diag.?workspaceId

// defaulting:
var retention = diag.?retentionDays ?? 30

// assertion (after a guard or a conditional resource):
var requiredWsId = wsId!  // “I promise it’s set here”
```

Docs: safe-dereference, null-forgiving; overview of nullability operators. ([Microsoft Learn][3])

---

# 4) Pattern: “tagged unions” for option sets (a.k.a. discriminated unions)

Bicep doesn’t have a built-in discriminator keyword, but you can **model** it using string-literal unions on a `kind` (or `type`) property, and make each variant’s payload shape explicit:

```bicep
type DataLakeAuth =
  | { kind: 'mi',  userAssignedIdentityId: string }   // Managed Identity
  | { kind: 'key', accountKey: string }               // Access key
  | { kind: 'sas', sasToken: string }                 // SAS

param auth DataLakeAuth

// Usage
var header = auth.kind == 'mi'
  ? 'ManagedIdentity ' + auth.userAssignedIdentityId
  : auth.kind == 'key'
    ? 'Key ' + auth.accountKey
    : 'Sas ' + auth.sasToken
```

Benefits:

* IDE narrows fields by `kind` value (similar to TS discriminated unions).
* You eliminate “illegal combinations” at compile time.

Background & prior discussions on tagged unions in Bicep. ([GitHub][4])

---

# 5) Pattern: “configuration set” types for environment overlays

Lift all “per-environment” knobs into a strongly typed config, then `switch` on environment to reduce drift.

```bicep
type Env = 'dev' | 'test' | 'prod'

type EnvConfig = {
  sku:  'B1' | 'P1v3'
  zoneRedundant: bool
  diag?: Diagnostics
  regions: string[] // or Region literal union from §2.1
}

param env Env

var envCfg = {
  dev:  { sku: 'B1',   zoneRedundant: false, regions: ['eastus'] }
  test: { sku: 'B1',   zoneRedundant: false, regions: ['eastus','westeurope'] }
  prod: { sku: 'P1v3', zoneRedundant: true,  regions: ['eastus','westeurope'] }
}[env] as EnvConfig
```

This mirrors the official **configuration set pattern** while remaining fully typed. ([Microsoft Learn][5])

---

# 6) Design “hard” contracts at module boundaries

## 6.1 Module inputs/outputs as types

Expose UDTs on both sides. Don’t pass raw bags of values.

```bicep
// module: vnet.bicep
type VnetInput = {
  name: string
  addressSpaces: string[]
  subnets: {
    name: string
    prefix: string
    nsgId?: string
  }[]
}

param input VnetInput

output subnetIds array = [for s in input.subnets: resourceId('Microsoft.Network/virtualNetworks/subnets', input.name, s.name)]
```

Consumers get strong IntelliSense and output typing automatically.

## 6.2 Guard optional outputs

If a module may output `null`, couple `.?`/`??` on the consumer side to keep type safety:

```bicep
module net './vnet.bicep' = {
  name: 'net'
  params: { input: vnetCfg }
}

var anySubnetId = net.outputs.subnetIds[?0]  // returns null if empty
var firstOrDefault = anySubnetId ?? resourceId('Microsoft.Resources/resourceGroups', resourceGroup().name)
```

Guidance on handling nullable module outputs. ([GitHub][6])

---

# 7) Encode naming & policy rules in types (and small helpers)

## 7.1 String-literal building blocks

Constrain SKUs, tiers, and locations into unions; combine with functions for computed names.

```bicep
type AppTier = 'basic' | 'standard' | 'premium'
type Location = 'eastus' | 'westeurope' | 'westus'

param tier AppTier
param loc  Location
param app  string

var name = toLower('${app}-${tier}-${loc}')
```

## 7.2 “Map” types for tags/policies

Keep tag shapes consistent across the estate:

```bicep
type TagPolicy = {
  env: 'dev' | 'test' | 'prod'
  owner: string
  // add metadata decorator if you want extra docs
}

@metadata({ doc: 'Required business tags for FinOps & ownership' })
param tags TagPolicy
```

Metadata in types & parameters. ([Azure Docs][7])

---

# 8) Optionality patterns without conditionals everywhere

## 8.1 Optional object sections via `?` + conditional spreads

Model “feature toggles” inside an object literal without large `if` blocks:

```bicep
param enableDiag bool
param diag Diagnostics?

resource sa 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: cfg.name
  location: resourceGroup().location
  sku: { name: cfg.sku }
  kind: 'StorageV2'
  properties: {
    // ...
  }
  // Only add diagnostic settings if both are set:
  // (use a separate module/resource for diag wiring as needed)
}

resource diagSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiag && diag != null) {
  name: 'storage-diag'
  scope: sa
  properties: {
    workspaceId: diag!.workspaceId
  }
}
```

The `if (...)` conditional on the resource plus `!` keeps compile-time types happy. Nullability operator docs. ([Microsoft Learn][8])

---

# 9) Make parameters pleasant *and* safe

| Need               | Technique                                                        |         |
| ------------------ | ---------------------------------------------------------------- | ------- |
| Optional param     | `param foo string?` (omit in `.bicepparam` or pass `null`)       |         |
| Enum-like param    | Literal union: `param sku 'B1'                                   | 'P1v3'` |
| Limit length/count | Decorators: `@minLength`, `@maxLength`, `@minValue`, `@maxValue` |         |
| Secure secrets     | `@secure()` with `string`/`object`                               |         |
| Describe intent    | `@description('…')` and `@metadata({ ... })`                     |         |

Docs: parameter types & decorators. ([Microsoft Learn][9])

---

# 10) “Type-first” validation—push errors left

## 10.1 Prefer types over runtime checks

* Illegal combinations → tagged unions (section 4).
* Legal values → literal unions (section 2).
* Optional/unknown → `?`, `.?`, `??`, `!` (section 3).

## 10.2 ARM “reducibility” rule for unions (gotcha)

Union members must share a **single underlying primitive** (all strings, or all ints). Mixed unions like `'a' \| 1` are invalid—design around it with enclosing objects. ([Microsoft Learn][2])

---

# 11) Real-world mini-example: strongly-typed ingress

> Goal: a single `Ingress` input that can be **Public IP**, **Private Link**, or **App Gateway**, each with its specific required fields.

```bicep
type PublicIpIngress = {
  kind: 'publicIp'
  sku: 'Basic' | 'Standard'
  dnsLabel?: string
}

type PrivateLinkIngress = {
  kind: 'privateLink'
  vnetId: string
  subnetName: string
}

type AppGwIngress = {
  kind: 'appGateway'
  appGatewayId: string
  listenerName: string
}

type Ingress = PublicIpIngress | PrivateLinkIngress | AppGwIngress

param ingress Ingress

// Example usage with narrowing
var isPublic = ingress.kind == 'publicIp'
var frontendName = isPublic ? '${ingress.dnsLabel ?? 'web'}-fe' : 'n/a'
```

This catches “forgot listenerName for App Gateway” **at compile time**.

---

# 12) IDE superpowers you unlock by typing everything

* Auto-completion of union members (locations/SKUs).
* Red squiggles when you feed a `null` into a non-nullable.
* Hover docs from `@description/@metadata`.
* Safer refactors by changing UDTs in one place.
  (Backed by Bicep’s language server.) ([Microsoft Learn][10])

---

# 13) Anti-patterns (and safer alternatives)

| Anti-pattern                                        | Why it hurts                  | Do instead                            |
| --------------------------------------------------- | ----------------------------- | ------------------------------------- |
| Giant `object` params with free-form strings        | Typos & silent drift          | Break into UDTs + unions              |
| Using `string` for everything (sku, location, tier) | No IntelliSense or validation | Literal unions or UDT enums           |
| Encoding “optional” with `''` or `0`                | Ambiguous; spreads bugs       | Use `?` + `.?.??.!`                   |
| Duplicating shapes across modules                   | Divergence over time          | Central `types.bicep` UDT library     |
| Conditional spaghetti                               | Hard to read/test             | Tagged unions + conditional resources |
| Post-deploy validation scripts                      | Catch errors late             | Move constraints into types first     |

---

# 14) Checklist: a “maximum types” module

1. All inputs/outputs are UDTs.
2. All categorical fields use literal unions.
3. All optional fields use `?`; consumer code uses `.?, ??, !`.
4. Environment choices come from a typed config map.
5. Module outputs never force consumers to slice through `object`—they’re strongly typed and documented.
6. No `@allowed` for shapes—use unions in types.
7. No magic strings/numbers—lift them into types.

---

## References & further reading

* **User-defined data types** (Bicep): [https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/user-defined-data-types](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/user-defined-data-types) ([Microsoft Learn][1])
* **Data types** (literals, unions, tuples, nullable): [https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/data-types](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/data-types) ([Microsoft Learn][2])
* **File structure & decorators** (`@allowed`, `@metadata`, etc.): [https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/file](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/file) ([Microsoft Learn][10])
* **Parameters** (decorators, examples): [https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/parameters](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/parameters) ([Microsoft Learn][9])
* **Nullability operators**: safe-dereference `.?` [https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/operator-safe-dereference](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/operator-safe-dereference) and null-forgiving `!` [https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/operator-null-forgiving](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/operator-null-forgiving) ([Microsoft Learn][3])
* **Config set pattern**: [https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/patterns-configuration-set](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/patterns-configuration-set) ([Microsoft Learn][5])
* **Nullable operators explainer** (blog): [https://johnlokerse.dev/2024/06/10/azure-bicep-nullability-operators-explained/](https://johnlokerse.dev/2024/06/10/azure-bicep-nullability-operators-explained/) ([Azure Cloud | John Lokerse][11])
* **Advanced Bicep tips** (pragmatic patterns): [https://azuretechinsider.com/advanced-tips-for-better-bicep-deployments/](https://azuretechinsider.com/advanced-tips-for-better-bicep-deployments/) ([azuretechinsider.com][12])

---

If you want, I can turn this into a **starter repo** with `types.bicep`, a few “typed modules” (VNet, App Service, Storage), and a param pack showing the config-set pattern and tagged unions in practice.

[1]: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/user-defined-data-types?utm_source=chatgpt.com "User-defined types in Bicep - Azure Resource Manager"
[2]: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/data-types?utm_source=chatgpt.com "Data types in Bicep - Azure Resource Manager"
[3]: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/operator-safe-dereference?utm_source=chatgpt.com "Bicep safe-dereference operator - Azure Resource Manager"
[4]: https://github.com/Azure/bicep/issues/9230?utm_source=chatgpt.com "Tagged union type declarations · Issue #9230 · Azure/bicep"
[5]: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/patterns-configuration-set?utm_source=chatgpt.com "Configuration set pattern - Azure Resource Manager"
[6]: https://github.com/Azure/bicep/issues/13160?utm_source=chatgpt.com "Using a nullable string output from a module as input for ..."
[7]: https://docs.azure.cn/en-us/azure-resource-manager/bicep/user-defined-data-types?utm_source=chatgpt.com "User-defined types in Bicep - Azure Resource Manager"
[8]: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/operator-null-forgiving?utm_source=chatgpt.com "Bicep null-forgiving operator - Azure Resource Manager"
[9]: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/parameters?utm_source=chatgpt.com "Parameters in Bicep files - Azure Resource Manager"
[10]: https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/file?utm_source=chatgpt.com "Bicep file structure and syntax - Azure Resource Manager"
[11]: https://johnlokerse.dev/2024/06/10/azure-bicep-nullability-operators-explained/?utm_source=chatgpt.com "Azure Bicep nullability operators explained"
[12]: https://azuretechinsider.com/advanced-tips-for-better-bicep-deployments/?utm_source=chatgpt.com "10 Advanced Tips for Better Bicep Deployments"
---

# 15) Typed app-hosting stack blueprint

Bringing the patterns together, the new `examples/app-hosting-stack.bicep` template composes the freshly added modules to demonstrate a modern application delivery chain without touching Kubernetes:

* **Edge** – `modules/edge/frontdoor.bicep` routes globally to your regional entry point with typed origin/route definitions and WAF policy linkage.
* **Regional ingress** – `modules/network/appgateway.bicep` terminates traffic on Application Gateway WAF v2 with strongly typed listeners, backends, and rule priorities.
* **API facade** – `modules/api/apim.bicep` provisions API Management with system-assigned identity so you can wire policies straight away.
* **Compute** – `modules/serverless/functionapp.bicep` powers the business logic with premium plan autoscale and VNet integration.
* **Data** – `modules/data/postgres-flexible.bicep` manages PostgreSQL Flexible Server (HA, backups, delegated subnet) via discriminated unions.
* **Messaging** – `modules/messaging/eventhub.bicep` gifts you an Event Hubs namespace with declarative hubs + consumer groups in loops.

> 🔗 Use `az deployment group create --template-file examples/app-hosting-stack.bicep ...` to explore the entire flow end-to-end.

The example leans heavily on the repo's shared types and exported helper functions, so every module boundary still benefits from IntelliSense, discriminated unions, and compile-time validation.
