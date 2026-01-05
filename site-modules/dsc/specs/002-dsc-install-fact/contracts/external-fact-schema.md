# Contract: External Fact File Format

**Feature**: 002-dsc-install-fact  
**Version**: 1.0.0  
**Type**: JSON Schema

---

## Purpose

This contract defines the JSON schema for the external fact file written by the `dsc` class and read by the `dsc_install_path` custom fact. This file serves as the interface between Puppet manifests (catalog application) and Facter (fact resolution).

---

## File Location

### Platform-Specific Paths

| Platform | File Path |
|----------|-----------|
| Windows | `C:/ProgramData/PuppetLabs/facter/facts.d/dsc_install.json` |
| Linux | `/etc/puppetlabs/facter/facts.d/dsc_install.json` |
| macOS | `/etc/puppetlabs/facter/facts.d/dsc_install.json` |

---

## JSON Schema

### Version 1.0.0

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "DSC Installation Fact",
  "description": "External fact file containing DSC installation path",
  "type": "object",
  "required": ["dsc_install_path"],
  "properties": {
    "dsc_install_path": {
      "type": "string",
      "description": "Absolute path to directory containing DSC binary",
      "minLength": 1,
      "pattern": "^(/|[A-Za-z]:)",
      "examples": [
        "/opt/dsc",
        "/usr/local/dsc",
        "C:/Program Files/DSC",
        "C:/custom/dsc"
      ]
    }
  },
  "additionalProperties": false
}
```

---

## Field Specifications

### `dsc_install_path`

**Type**: `string`  
**Required**: `true`  
**Description**: Absolute path to the directory containing the DSC binary (not including the binary name itself).

**Constraints**:
- Must be non-empty string
- Must be absolute path:
  - Unix: Starts with `/`
  - Windows: Starts with drive letter (e.g., `C:/`)
- Should not include trailing slash
- Should not include the binary name (`dsc` or `dsc.exe`)

**Platform-Specific Values**:

| Platform | Default Value | Custom Example |
|----------|---------------|----------------|
| Windows | `C:/Program Files/DSC` | `C:/custom/dsc` |
| Linux | `/opt/dsc` | `/usr/local/dsc` |
| macOS | `/usr/local/dsc` | `/opt/custom/dsc` |

---

## Examples

### Valid Examples

**Example 1: Windows Default**
```json
{
  "dsc_install_path": "C:/Program Files/DSC"
}
```

**Example 2: Linux Custom**
```json
{
  "dsc_install_path": "/usr/local/dsc"
}
```

**Example 3: macOS Default**
```json
{
  "dsc_install_path": "/usr/local/dsc"
}
```

**Example 4: Windows Custom with Spaces**
```json
{
  "dsc_install_path": "C:/Program Files/Custom DSC"
}
```

### Invalid Examples

**Example 1: Missing Required Field**
```json
{
  "some_other_field": "value"
}
```
❌ Error: Missing required field `dsc_install_path`

**Example 2: Null Value**
```json
{
  "dsc_install_path": null
}
```
❌ Error: Value must be string, not null

**Example 3: Empty String**
```json
{
  "dsc_install_path": ""
}
```
❌ Error: String must have minimum length of 1

**Example 4: Relative Path**
```json
{
  "dsc_install_path": "relative/path/to/dsc"
}
```
❌ Error: Path must be absolute (start with `/` or drive letter)

**Example 5: Includes Binary Name**
```json
{
  "dsc_install_path": "/opt/dsc/dsc"
}
```
⚠️ Warning: Path should be directory, not include binary name (though parser will tolerate this)

---

## Usage Contract

### Writer (Puppet Manifest - `dsc` class)

**Responsibilities**:
1. Create parent directory if not exists
2. Write valid JSON conforming to schema
3. Set proper file permissions (644 on Unix, inherit on Windows)
4. Update file when `install_dir` parameter changes
5. Use `to_json_pretty` for human-readable output

**Implementation Example** (Puppet):
```puppet
$fact_dir = $facts['os']['family'] ? {
  'windows' => 'C:/ProgramData/PuppetLabs/facter/facts.d',
  default   => '/etc/puppetlabs/facter/facts.d',
}

file { $fact_dir:
  ensure => directory,
}

file { "${fact_dir}/dsc_install.json":
  ensure  => file,
  content => to_json_pretty({
    'dsc_install_path' => $actual_install_dir,
  }),
  mode    => '0644',
  require => File[$fact_dir],
}
```

### Reader (Custom Fact - `dsc_install_path`)

**Responsibilities**:
1. Check file existence before reading
2. Handle JSON parse errors gracefully
3. Return `nil` on any error (don't raise exceptions)
4. Validate path is non-empty string
5. Log debug messages for troubleshooting

**Implementation Example** (Ruby):
```ruby
Facter.add(:dsc_install_path) do
  setcode do
    fact_file = case Facter.value(:kernel)
                when 'windows'
                  'C:/ProgramData/PuppetLabs/facter/facts.d/dsc_install.json'
                else
                  '/etc/puppetlabs/facter/facts.d/dsc_install.json'
                end
    
    next nil unless File.exist?(fact_file)
    
    begin
      require 'json'
      data = JSON.parse(File.read(fact_file))
      path = data['dsc_install_path']
      
      # Validate
      next nil unless path.is_a?(String) && !path.empty?
      
      path
    rescue JSON::ParserError, Errno::EACCES
      nil
    end
  end
end
```

---

## Versioning

### Current Version: 1.0.0

**Changes in this version**:
- Initial schema definition
- Single required field: `dsc_install_path`
- Absolute path validation

### Future Compatibility

**Backward Compatibility Promise**:
- `dsc_install_path` field will never be renamed or removed
- Additional optional fields may be added in future versions
- Readers should ignore unknown fields (`additionalProperties: false` only for validation)

**Potential Future Fields** (not implemented):
- `dsc_version`: Version of DSC installed (e.g., "v3.1.2")
- `dsc_installed_at`: Timestamp of installation
- `dsc_managed_by_module`: Boolean flag

---

## Error Handling

### File Read Errors

| Error | Cause | Fact Return Value |
|-------|-------|-------------------|
| `Errno::ENOENT` | File not found | `nil` (expected when class not used) |
| `Errno::EACCES` | Permission denied | `nil` (log warning) |
| `JSON::ParserError` | Invalid JSON | `nil` (log debug) |
| Missing key | Schema violation | `nil` (log debug) |
| Wrong type | Schema violation | `nil` (log debug) |

### Provider Handling

When fact returns `nil`, provider falls back to platform defaults:

```ruby
def dsc_binary_path
  custom_path = Facter.value(:dsc_install_path)
  
  if custom_path && !custom_path.empty?
    # Use custom path
    binary = kernel == 'windows' ? 'dsc.exe' : 'dsc'
    return File.join(custom_path, binary)
  end
  
  # Fallback to defaults
  case kernel
  when 'windows'
    'C:\\Windows\\DSC\\dsc.exe'
  else
    '/opt/DSC/dsc'
  end
end
```

---

## Testing

### Schema Validation Tests

Test cases for JSON schema validation:

1. ✅ Valid JSON with required field
2. ❌ Missing required field
3. ❌ Null value
4. ❌ Empty string
5. ❌ Relative path (Unix)
6. ❌ Relative path (Windows)
7. ✅ Absolute path with spaces
8. ✅ Additional unknown fields (tolerance)

### Round-Trip Tests

Verify write → read cycle:

```ruby
it 'manifest writes and fact reads correctly' do
  # Write fact file
  data = { 'dsc_install_path' => '/custom/path' }
  File.write(fact_file, JSON.pretty_generate(data))
  
  # Read via fact
  expect(Facter.value(:dsc_install_path)).to eq('/custom/path')
end
```

---

## Security Considerations

### File Permissions

**Unix/Linux/macOS**:
- Owner: `root`
- Mode: `0644` (readable by all, writable by owner only)
- Why: Prevents non-root users from tampering with fact data

**Windows**:
- Inherits permissions from parent directory (`ProgramData/PuppetLabs`)
- Typically readable by all, writable by SYSTEM and Administrators

### Path Injection

**Mitigation**: Provider validates path exists and binary is executable before use.

```ruby
def dsc_binary_available?
  path = dsc_binary_path
  File.exist?(path) && File.executable?(path)
end
```

**Risk**: If fact file is compromised, attacker could point to malicious binary.  
**Mitigation**: File only writable by root/SYSTEM, same privilege level as Puppet itself.

---

## Contract Compliance

### Writer Compliance Checklist

- [ ] Creates parent directory if not exists
- [ ] Writes valid JSON matching schema
- [ ] Uses absolute path for `dsc_install_path`
- [ ] Sets file mode to 0644 (Unix)
- [ ] Updates file when parameter changes
- [ ] Uses `to_json_pretty` for formatting

### Reader Compliance Checklist

- [ ] Checks file existence before reading
- [ ] Handles JSON parse errors
- [ ] Returns `nil` on errors (no exceptions)
- [ ] Validates path is non-empty string
- [ ] Logs debug messages
- [ ] Ignores unknown fields

### Consumer Compliance Checklist

- [ ] Checks for `nil` before using fact value
- [ ] Provides fallback when fact is `nil`
- [ ] Validates path exists before executing binary
- [ ] Constructs full binary path (fact + binary name)
- [ ] Handles platform differences (exe vs no extension)

---

**Contract Version**: 1.0.0  
**Last Updated**: 2025-12-16  
**Status**: Active
