# Data Model: Puppet-DSC V3 Integration

**Feature**: 001-dsc-v3-integration  
**Phase**: 1 - Data Model Design  
**Date**: 2025-11-10

---

## Overview

This document defines the data structures used by the puppetlabs-dsc module. Since this is a translation layer between Puppet and DSC, the primary entities are:
1. Puppet resource declarations (input from manifests)
2. DSC configuration documents (translated YAML sent to DSC)
3. DSC result objects (JSON returned from DSC)

---

## Entity: Puppet dsc_resource Declaration

**Purpose**: Represents a single DSC resource managed through Puppet

**Location**: Puppet manifests (`.pp` files)

**Attributes**:

| Attribute | Type           | Required | Default | Description                                                     |
|-----------|----------------|----------|---------|-----------------------------------------------------------------|
| name      | String         | Yes      | -       | Unique identifier for this resource instance (Puppet namevar)   |
| type      | String         | Yes      | -       | DSC resource type (format: `ModuleName/ResourceType`)           |
| input     | Hash           | Yes      | -       | DSC resource properties as key-value pairs                      |
| adapter   | String         | No       | nil     | Optional DSC adapter name for non-native resources              |
| ensure    | Enum           | No       | present | Resource existence state: `present` or `absent`                 |

**Validation Rules**:
- `name`: Non-empty string, unique within catalog
- `type`: Must match pattern `[A-Za-z0-9._-]+/[A-Za-z0-9._-]+` (module/resource)
- `input`: Must be a Hash, cannot be empty
- `adapter`: If specified, must be non-empty string
- `ensure`: Must be `present` or `absent`

**Example**:
```puppet
dsc_resource { 'configure_registry_key':
  type  => 'Microsoft.Windows/Registry',
  input => {
    keyPath   => 'HKLM:\Software\MyApp',
    valueName => 'ConfigPath',
    valueData => 'C:\ProgramData\MyApp\config.json',
  },
  ensure => present,
}
```

**Relationships**:
- May depend on other Puppet resources (via `require`, `before`, etc.)
- May notify other Puppet resources (via `notify`, `subscribe`)
- Translates to one DSC Configuration Document

---

## Entity: DSC Configuration Document

**Purpose**: YAML document sent to `dsc config set` command

**Location**: Generated dynamically by provider, passed via stdin

**Schema**: DSC V3 Configuration Document Schema  
**Schema URL**: `https://raw.githubusercontent.com/PowerShell/DSC/main/schemas/2024/04/config/document.json`

**Structure**:
```yaml
$schema: <schema-url>
resources:
  - name: <string>
    type: <string>
    adapter: <string>  # Optional
    properties:
      <key>: <value>
      ...
```

**Attributes**:

| Field                  | Type   | Required | Description                                        |
|------------------------|--------|----------|----------------------------------------------------|
| $schema                | String | Yes      | DSC schema URL for validation                      |
| resources              | Array  | Yes      | Array of resource configurations (always length 1) |
| resources[].name       | String | Yes      | Resource instance name (from Puppet namevar)       |
| resources[].type       | String | Yes      | DSC resource type (from Puppet `type` param)       |
| resources[].adapter    | String | No       | Adapter name (from Puppet `adapter` param)         |
| resources[].properties | Object | Yes      | Resource properties (from Puppet `input` param)    |

**Generation Logic**:
1. Start with schema URL
2. Create resource array with single element
3. Map Puppet parameters to DSC fields:
   - `name` → `resources[0].name`
   - `type` → `resources[0].type`
   - `adapter` → `resources[0].adapter` (if present)
   - `input` → `resources[0].properties`
4. Convert to YAML using Ruby's `YAML.dump()`

**Example**:
```yaml
$schema: https://raw.githubusercontent.com/PowerShell/DSC/main/schemas/2024/04/config/document.json
resources:
  - name: configure_registry_key
    type: Microsoft.Windows/Registry
    properties:
      keyPath: 'HKLM:\Software\MyApp'
      valueName: ConfigPath
      valueData: C:\ProgramData\MyApp\config.json
```

**Special Cases**:
- **ensure => absent**: Add `_ensure: absent` to properties hash (DSC convention)
- **adapter specified**: Include `adapter` field in resource object
- **Complex properties**: Nested hashes and arrays preserved in YAML structure

---

## Entity: DSC Result Object

**Purpose**: JSON output from `dsc config set` or `dsc config test` commands

**Location**: Stdout from DSC command, parsed by provider

**Schema**: DSC V3 Result Schema

**Structure**:
```json
{
  "results": [
    {
      "name": "<string>",
      "type": "<string>",
      "result": {
        "beforeState": { <object> },
        "afterState": { <object> },
        "changedProperties": [ <string>, ... ]
      }
    }
  ],
  "messages": [
    {
      "level": "<string>",
      "message": "<string>"
    }
  ],
  "hadErrors": <boolean>
}
```

**Attributes**:

| Field                               | Type    | Always Present | Description                                      |
|-------------------------------------|---------|----------------|--------------------------------------------------|
| results                             | Array   | Yes            | Array of resource results (expect length 1)      |
| results[].name                      | String  | Yes            | Resource instance name                           |
| results[].type                      | String  | Yes            | DSC resource type                                |
| results[].result.beforeState        | Object  | Yes            | Resource state before operation                  |
| results[].result.afterState         | Object  | Yes            | Resource state after operation                   |
| results[].result.changedProperties  | Array   | Yes            | List of properties that changed (empty if none)  |
| messages                            | Array   | Yes            | Informational/warning/error messages             |
| messages[].level                    | String  | Yes            | Message severity: Info, Warning, Error           |
| messages[].message                  | String  | Yes            | Human-readable message text                      |
| hadErrors                           | Boolean | Yes            | True if operation encountered errors             |

**Parsing Logic**:
1. Parse stdout as JSON using `JSON.parse()`
2. Check `hadErrors` field:
   - If `true`: Extract error messages and raise `Puppet::Error`
   - If `false`: Continue processing
3. Extract first result from `results` array (always single resource)
4. Check `changedProperties` array:
   - If empty: Resource already in desired state (no changes)
   - If non-empty: Resource was modified (report changes to Puppet)
5. Return change status to Puppet

**Example (No Changes)**:
```json
{
  "results": [
    {
      "name": "configure_registry_key",
      "type": "Microsoft.Windows/Registry",
      "result": {
        "beforeState": { "keyPath": "HKLM:\\Software\\MyApp", "valueName": "ConfigPath", "valueData": "C:\\ProgramData\\MyApp\\config.json" },
        "afterState": { "keyPath": "HKLM:\\Software\\MyApp", "valueName": "ConfigPath", "valueData": "C:\\ProgramData\\MyApp\\config.json" },
        "changedProperties": []
      }
    }
  ],
  "messages": [],
  "hadErrors": false
}
```

**Example (With Changes)**:
```json
{
  "results": [
    {
      "name": "configure_registry_key",
      "type": "Microsoft.Windows/Registry",
      "result": {
        "beforeState": { "keyPath": "HKLM:\\Software\\MyApp", "valueName": "ConfigPath", "valueData": "C:\\OldPath\\config.json" },
        "afterState": { "keyPath": "HKLM:\\Software\\MyApp", "valueName": "ConfigPath", "valueData": "C:\\ProgramData\\MyApp\\config.json" },
        "changedProperties": ["valueData"]
      }
    }
  ],
  "messages": [
    { "level": "Info", "message": "Updated registry value" }
  ],
  "hadErrors": false
}
```

**Example (With Errors)**:
```json
{
  "results": [],
  "messages": [
    { "level": "Error", "message": "Resource type 'Foo/Bar' not found. Ensure the DSC module is installed." }
  ],
  "hadErrors": true
}
```

---

## Data Flow

```
┌─────────────────────────┐
│ Puppet Manifest         │
│                         │
│ dsc_resource { 'name':  │
│   type  => 'Mod/Res',   │
│   input => { ... },     │
│ }                       │
└───────────┬─────────────┘
            │
            │ Puppet catalog compilation
            │
            ▼
┌─────────────────────────┐
│ Provider: dsc.rb        │
│                         │
│ - Validate parameters   │
│ - Generate DSC YAML     │
│ - Execute via pwshlib   │
└───────────┬─────────────┘
            │
            │ YAML document via stdin
            │
            ▼
┌─────────────────────────┐
│ DSC V3 CLI              │
│                         │
│ dsc config set          │
│   --format yaml         │
│   --output-format json  │
└───────────┬─────────────┘
            │
            │ JSON result to stdout
            │
            ▼
┌─────────────────────────┐
│ Provider: dsc.rb        │
│                         │
│ - Parse JSON            │
│ - Check errors          │
│ - Report changes        │
└───────────┬─────────────┘
            │
            │ Resource state and changes
            │
            ▼
┌─────────────────────────┐
│ Puppet Report           │
│                         │
│ - Resource status       │
│ - Changed properties    │
│ - Error messages        │
└─────────────────────────┘
```

---

## State Transitions

### Resource Lifecycle

```
┌─────────────┐
│   Catalog   │
│  Compiled   │
└──────┬──────┘
       │
       ▼
┌─────────────┐      Yes      ┌─────────────┐
│  exists?    │─────────────▶ │   No-op     │
│  (test)     │               │  (in sync)  │
└──────┬──────┘               └─────────────┘
       │ No
       ▼
┌─────────────┐
│   create    │
│  (set)      │
└──────┬──────┘
       │
       ▼
┌─────────────┐      Empty     ┌─────────────┐
│ Parse       │─────────────▶  │   No-op     │
│ changes     │                │ (converged) │
└──────┬──────┘                └─────────────┘
       │ Non-empty
       ▼
┌─────────────┐
│   Report    │
│   Changes   │
└─────────────┘
```

### Error States

```
┌─────────────┐
│   Execute   │
│  DSC cmd    │
└──────┬──────┘
       │
       ├─▶ Exit code 0 ──────────▶ Parse JSON
       │                              │
       │                              ├─▶ hadErrors: false ──▶ Success
       │                              │
       │                              └─▶ hadErrors: true ───▶ Raise Puppet::Error
       │
       └─▶ Exit code != 0 ─────────▶ Raise Puppet::Error (DSC command failed)
```

---

## Validation Rules

### Type Parameter Validation

```ruby
validate do |value|
  raise ArgumentError, "type must be a string" unless value.is_a?(String)
  raise ArgumentError, "type must not be empty" if value.empty?
  raise ArgumentError, "type must contain a '/' separator" unless value.include?('/')
  raise ArgumentError, "type format must be ModuleName/ResourceType" unless value =~ /^[A-Za-z0-9._-]+\/[A-Za-z0-9._-]+$/
end
```

### Input Parameter Validation

```ruby
validate do |value|
  raise ArgumentError, "input must be a hash" unless value.is_a?(Hash)
  raise ArgumentError, "input must not be empty" if value.empty?
  
  # Recursive validation for nested structures
  validate_hash_values(value)
end

def validate_hash_values(hash)
  hash.each do |key, value|
    raise ArgumentError, "input keys must be strings or symbols" unless key.is_a?(String) || key.is_a?(Symbol)
    
    case value
    when Hash
      validate_hash_values(value)
    when Array
      value.each { |item| validate_hash_values(item) if item.is_a?(Hash) }
    when String, Integer, Float, TrueClass, FalseClass, NilClass
      # Valid types
    else
      raise ArgumentError, "input contains unsupported type: #{value.class}"
    end
  end
end
```

### Adapter Parameter Validation

```ruby
validate do |value|
  raise ArgumentError, "adapter must be a string" unless value.is_a?(String)
  raise ArgumentError, "adapter must not be empty" if value.empty?
end
```

---

## Type Mappings

### Puppet to DSC Type Mapping

| Puppet Type | DSC YAML Type | Notes                                    |
|-------------|---------------|------------------------------------------|
| String      | string        | Direct mapping                           |
| Integer     | integer       | Direct mapping                           |
| Float       | number        | Direct mapping                           |
| Boolean     | boolean       | Direct mapping                           |
| Hash        | object        | Nested structure preserved               |
| Array       | array         | Ordered list preserved                   |
| Symbol      | string        | Converted to string (Ruby-specific type) |
| nil         | null          | Represents absence of value              |

### DSC to Puppet Change Reporting

| DSC Change Type         | Puppet Report       | Description                         |
|-------------------------|---------------------|-------------------------------------|
| changedProperties: []   | No changes          | Resource already in desired state   |
| changedProperties: [x]  | Changed             | Properties modified                 |
| hadErrors: true         | Failed              | DSC operation failed                |
| beforeState: null       | Created             | Resource created (did not exist)    |
| afterState: null        | Destroyed           | Resource removed (ensure: absent)   |

---

## Phase 1 Complete

All data models, validation rules, and type mappings have been defined. Ready to proceed to contract definitions.
