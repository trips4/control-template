# Contract: DSC V3 CLI Interface

**Feature**: 001-dsc-v3-integration  
**Phase**: 1 - API Contracts  
**Date**: 2025-11-10  
**External System**: Microsoft DSC V3 Command-Line Interface

---

## Overview

This contract defines the interface between the puppetlabs-dsc provider and the DSC V3 command-line tool. It documents the expected command syntax, input formats, output formats, and error conditions.

**Contract Type**: External CLI Contract  
**Provider**: Microsoft DSC V3  
**Consumer**: puppetlabs-dsc Puppet provider  
**Communication Method**: Process execution with stdin/stdout  
**Data Format**: YAML input, JSON output

---

## Command: dsc config set

**Purpose**: Apply a DSC configuration to bring resources into desired state

**Syntax**:
```bash
dsc config set [OPTIONS]
```

### Options

| Option               | Type     | Required | Default | Description                                    |
|----------------------|----------|----------|---------|------------------------------------------------|
| --format             | string   | No       | auto    | Input format: `yaml`, `json`, or `auto`        |
| --output-format      | string   | No       | json    | Output format: `json` or `yaml`                |
| --what-if            | flag     | No       | false   | Simulate changes without applying              |
| --document           | filepath | No       | stdin   | Path to configuration document (use stdin)     |

### Input Document Structure (YAML)

```yaml
$schema: https://raw.githubusercontent.com/PowerShell/DSC/main/schemas/2024/04/config/document.json
resources:
  - name: string                    # Required: Resource instance identifier
    type: string                    # Required: Format "ModuleName/ResourceType"
    adapter: string                 # Optional: Adapter name for non-native resources
    properties:                     # Required: Resource-specific properties
      <property_name>: <value>      # Key-value pairs defined by DSC resource
      ...
```

**Contract Guarantees**:
- Schema URL must be included for validation
- `resources` is an array (provider always sends single element)
- `name` must be unique within document (provider ensures this)
- `type` must reference an installed DSC resource
- `properties` structure validated by DSC resource schema
- `adapter` field included only when specified

### Output Structure (JSON)

**Success Response**:
```json
{
  "results": [
    {
      "name": "string",
      "type": "string",
      "result": {
        "beforeState": {
          "property1": "value1",
          ...
        },
        "afterState": {
          "property1": "value1",
          ...
        },
        "changedProperties": ["property1", ...]
      }
    }
  ],
  "messages": [
    {
      "level": "Info|Warning|Error",
      "message": "string"
    }
  ],
  "hadErrors": false
}
```

**Error Response**:
```json
{
  "results": [],
  "messages": [
    {
      "level": "Error",
      "message": "string"
    }
  ],
  "hadErrors": true
}
```

**Contract Guarantees**:
- `results` array length matches input resources (1 in our case)
- `changedProperties` is empty array if no changes made
- `hadErrors` is boolean (never null or missing)
- `messages` array always present (may be empty)
- Exit code 0 for successful operations (even if hadErrors: true)
- Exit code non-zero for CLI failures (invalid arguments, etc.)

### Exit Codes

| Code | Meaning                          | Provider Action                           |
|------|----------------------------------|-------------------------------------------|
| 0    | Command executed                 | Parse JSON, check `hadErrors` field       |
| 1    | Invalid arguments                | Raise error (provider bug)                |
| 2    | Resource type not found          | Raise error with installation guidance    |
| 3    | Resource execution failed        | Already reported in JSON `hadErrors`      |
| 4    | Configuration validation failed  | Raise error (provider generated bad YAML) |

---

## Command: dsc config test

**Purpose**: Check if resources are in desired state without making changes

**Syntax**:
```bash
dsc config test [OPTIONS]
```

### Options

Same as `dsc config set` except `--what-if` is not applicable.

### Output Structure (JSON)

```json
{
  "results": [
    {
      "name": "string",
      "type": "string",
      "result": {
        "actualState": {
          "property1": "value1",
          ...
        },
        "desiredState": {
          "property1": "value1",
          ...
        },
        "inDesiredState": true|false,
        "differingProperties": ["property1", ...]
      }
    }
  ],
  "messages": [],
  "hadErrors": false
}
```

**Contract Guarantees**:
- `inDesiredState` boolean indicates if resource matches desired state
- `differingProperties` lists properties that don't match (empty if in desired state)
- No state modifications made (read-only operation)

---

## Error Scenarios

### Scenario: DSC Module Not Installed

**Input**:
```yaml
resources:
  - name: example
    type: NonExistent/Resource
    properties:
      foo: bar
```

**Output**:
```json
{
  "results": [],
  "messages": [
    {
      "level": "Error",
      "message": "Resource type 'NonExistent/Resource' could not be found. Ensure the DSC module is installed."
    }
  ],
  "hadErrors": true
}
```

**Provider Response**: Raise `Puppet::Error` with message: "DSC resource 'example' failed: Resource type 'NonExistent/Resource' could not be found. Ensure the DSC module is installed."

---

### Scenario: Property Validation Failed

**Input**:
```yaml
resources:
  - name: example
    type: Microsoft.Windows/Registry
    properties:
      keyPath: "InvalidPath"
```

**Output**:
```json
{
  "results": [],
  "messages": [
    {
      "level": "Error",
      "message": "Property 'keyPath' must be a valid registry path starting with HKLM:\\ or HKCU:\\"
    }
  ],
  "hadErrors": true
}
```

**Provider Response**: Raise `Puppet::Error` with message: "DSC resource 'example' failed: Property 'keyPath' must be a valid registry path starting with HKLM:\\ or HKCU:\\"

---

### Scenario: Resource Execution Failed

**Input**:
```yaml
resources:
  - name: example
    type: Microsoft.Windows/Registry
    properties:
      keyPath: "HKLM:\\Software\\ProtectedKey"
      valueName: "Value"
      valueData: "Data"
```

**Output**:
```json
{
  "results": [
    {
      "name": "example",
      "type": "Microsoft.Windows/Registry",
      "result": {
        "beforeState": null,
        "afterState": null,
        "changedProperties": []
      }
    }
  ],
  "messages": [
    {
      "level": "Error",
      "message": "Access denied: Cannot write to registry key"
    }
  ],
  "hadErrors": true
}
```

**Provider Response**: Raise `Puppet::Error` with message: "DSC resource 'example' failed: Access denied: Cannot write to registry key"

---

## Data Type Contracts

### String Properties

**DSC Expectation**: UTF-8 encoded strings  
**Provider Guarantees**: All Puppet strings converted to UTF-8 in YAML  
**Special Cases**: Backslashes escaped in YAML (e.g., Windows paths)

### Numeric Properties

**DSC Expectation**: JSON numbers (integers or floats)  
**Provider Guarantees**: Puppet Integer/Float types preserved in YAML  
**Range**: DSC resources define valid ranges (provider does not validate)

### Boolean Properties

**DSC Expectation**: JSON boolean (`true` or `false`)  
**Provider Guarantees**: Puppet boolean types (`true`/`false`) converted to YAML booleans  
**Special Cases**: String values `"true"`/`"false"` not automatically converted

### Array Properties

**DSC Expectation**: JSON arrays with homogeneous or heterogeneous elements  
**Provider Guarantees**: Puppet arrays preserved in YAML, order maintained  
**Nesting**: Nested arrays and hashes supported

### Object Properties

**DSC Expectation**: JSON objects (key-value pairs)  
**Provider Guarantees**: Puppet hashes converted to YAML objects  
**Keys**: String keys required (symbols converted to strings)

---

## Performance Characteristics

### Command Execution Time

| Operation      | Expected Duration | Notes                                      |
|----------------|-------------------|--------------------------------------------|
| dsc config set | 1-10 seconds      | Varies by resource type and complexity     |
| dsc config test| 0.5-5 seconds     | Faster than set (no modifications)         |
| First invocation| +2 seconds       | DSC module loading overhead                |
| Subsequent     | <1 second         | Modules cached in PowerShell session       |

**Provider Implications**: 
- Use persistent PowerShell sessions (via pwshlib) to amortize loading overhead
- Expect per-resource overhead of 1-2 seconds
- Catalog compilation with 50 DSC resources: ~60-100 seconds (acceptable per spec)

---

## Versioning and Compatibility

**Contract Version**: DSC V3 (as of 2024-04)  
**Minimum DSC Version**: 3.0.0  
**Schema Stability**: DSC V3 schema considered stable; breaking changes will increment major version  
**Provider Assumptions**:
- Schema URL remains valid
- JSON output structure backward compatible within DSC V3.x
- New fields may be added (provider ignores unknown fields)
- Existing fields will not be removed or change type

---

## Testing Contract Compliance

### Unit Tests (Mocked)

Provider unit tests mock DSC responses based on this contract:
```ruby
# Mock successful set with changes
let(:dsc_output) do
  {
    results: [{
      name: 'test',
      type: 'Mod/Res',
      result: {
        beforeState: { foo: 'old' },
        afterState: { foo: 'new' },
        changedProperties: ['foo']
      }
    }],
    messages: [],
    hadErrors: false
  }.to_json
end
```

### Integration Tests (Real DSC)

Acceptance tests verify contract compliance with actual DSC V3:
```ruby
it 'parses DSC output correctly' do
  apply_manifest(manifest, catch_failures: true)
  # Verify Puppet report matches DSC output structure
end
```

---

## Contract Monitoring

**Change Detection**: 
- Monitor DSC releases for schema changes
- Test suite validates contract assumptions on each DSC version update
- Breaking changes require provider updates before adopting new DSC version

**Deprecation Policy**:
- If DSC V4 introduces breaking changes, provider will support DSC V3 for 12 months
- Deprecation warnings added if DSC V3 support will be removed

---

**Contract Established**: 2025-11-10  
**Last Verified**: 2025-11-10  
**Next Review**: When DSC 3.1+ releases or 2026-01-10 (whichever comes first)
