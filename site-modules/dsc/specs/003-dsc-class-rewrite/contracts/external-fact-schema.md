# Contract: External Fact File Schema

**Feature**: 003-dsc-class-rewrite  
**Version**: 1.0.0  
**Date**: 2025-12-16

## Purpose

This contract defines the structure and validation rules for the external fact file that communicates DSC installation location from the `dsc` class to the `dsc_resource` provider.

## File Location

**Windows**: `C:/ProgramData/PuppetLabs/facter/facts.d/dsc_install.json`  
**Unix/Linux/macOS**: `/etc/puppetlabs/facter/facts.d/dsc_install.json`

## JSON Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["dsc_install_path"],
  "properties": {
    "dsc_install_path": {
      "type": "string",
      "description": "Absolute path to the directory containing the DSC binary (excluding the binary filename)",
      "pattern": "^(/|[A-Za-z]:/).*",
      "minLength": 1,
      "examples": [
        "/opt/dsc",
        "/usr/local/dsc",
        "C:/Program Files/DSC",
        "/custom/path/to/dsc"
      ]
    }
  },
  "additionalProperties": false
}
```

## Field Specifications

### `dsc_install_path`

**Type**: String  
**Required**: Yes  
**Format**: Absolute path (Unix or Windows format)  
**Validation**:
- Must start with `/` (Unix) or `<drive>:/` (Windows)
- Must not be empty
- Must not include trailing slash
- Must not include the binary filename (`dsc` or `dsc.exe`)

**Valid Examples**:
```json
{
  "dsc_install_path": "/opt/dsc"
}
```

```json
{
  "dsc_install_path": "C:/Program Files/DSC"
}
```

```json
{
  "dsc_install_path": "/usr/local/dsc"
}
```

**Invalid Examples**:

```json
{
  "dsc_install_path": "opt/dsc"
}
// Invalid: Not an absolute path

{
  "dsc_install_path": "/opt/dsc/"
}
// Invalid: Trailing slash (though implementation may tolerate this)

{
  "dsc_install_path": "/opt/dsc/dsc"
}
// Invalid: Includes binary filename

{
  "dsc_install_path": ""
}
// Invalid: Empty string
```

## File Permissions

**Unix/Linux/macOS**:
- Owner: root
- Group: root
- Mode: 0644 (rw-r--r--)

**Windows**:
- Standard file permissions (readable by all users)

## Lifecycle

### Writer (manifests/init.pp)

**Responsibility**: Create or update the fact file after DSC installation

**Behavior**:
1. Ensure fact directory exists (`$fact_dir`)
2. Write JSON file with `dsc_install_path` set to `$actual_install_dir`
3. Set appropriate file permissions (0644 on Unix)
4. Use `to_json_pretty()` for human-readable formatting

**Code Example**:
```puppet
file { "${fact_dir}/dsc_install.json":
  ensure  => file,
  content => to_json_pretty({
      'dsc_install_path' => $actual_install_dir,
  }),
  mode    => '0644',
  require => File[$fact_dir],
}
```

### Reader (lib/facter/dsc_install_path.rb)

**Responsibility**: Load the fact file and expose `dsc_install_path` as a Facter fact

**Behavior**:
1. Determine platform-specific fact file path
2. Check if file exists (`File.exist?`)
3. Read and parse JSON (`JSON.parse(File.read(...))`)
4. Extract `dsc_install_path` value
5. Return the path string, or `nil` if:
   - File doesn't exist
   - JSON is malformed
   - Field is missing
   - Value is empty/null

**Error Handling**: Gracefully return `nil` on any errors (file not found, permission denied, parse errors). Do not raise exceptions.

**Code Example**:
```ruby
Facter.add(:dsc_install_path) do
  setcode do
    fact_file = case Facter.value(:kernel)
                when 'windows'
                  'C:/ProgramData/PuppetLabs/facter/facts.d/dsc_install.json'
                else
                  '/etc/puppetlabs/facter/facts.d/dsc_install.json'
                end

    if File.exist?(fact_file)
      begin
        data = JSON.parse(File.read(fact_file))
        path = data['dsc_install_path']
        path.to_s.empty? ? nil : path
      rescue JSON::ParserError, Errno::EACCES
        nil
      end
    else
      nil
    end
  end
end
```

### Consumer (lib/puppet/provider/dsc_resource/dsc_resource.rb)

**Responsibility**: Use the exposed fact to locate DSC binary for invocation

**Behavior**:
1. Call `Facter.value(:dsc_install_path)` to get installation directory
2. If value is `nil` or empty, fall back to platform defaults
3. Construct full binary path: `File.join(install_dir, binary_name)`
4. Use full path for DSC invocations

**Code Example**:
```ruby
def dsc_binary_path
  require 'facter'
  
  custom_path = Facter.value(:dsc_install_path)
  
  if custom_path && !custom_path.empty?
    binary_name = Facter.value(:kernel) == 'windows' ? 'dsc.exe' : 'dsc'
    return File.join(custom_path, binary_name)
  end
  
  # Fall back to defaults
  case Facter.value(:kernel)
  when 'windows'
    'C:\\Windows\\DSC\\dsc.exe'
  else
    '/opt/DSC/dsc'
  end
end
```

## Versioning

**Current Version**: 1.0.0

**Compatibility**:
- Forward compatible: New fields may be added in future versions
- Backward compatible: `dsc_install_path` field will remain required and in the same format

**Version History**:
- **1.0.0** (2025-12-16): Initial schema definition

## Testing Requirements

### Unit Tests (Writer)

- Test file creation with valid path
- Test file permissions (Unix)
- Test JSON formatting
- Test directory creation if missing

### Unit Tests (Reader)

- Test successful fact loading with valid file
- Test `nil` return when file missing
- Test `nil` return when JSON malformed
- Test `nil` return when field missing
- Test `nil` return when value empty
- Test platform-specific path selection

### Integration Tests (End-to-End)

- Test fact file written by manifest is readable by custom fact
- Test provider can use fact to locate DSC
- Test custom `install_dir` propagates through entire chain
- Test fallback to defaults when fact file missing

## Change Management

**Breaking Changes**: Any modification to the `dsc_install_path` field format or removal of the field requires a major version bump and migration path.

**Non-Breaking Changes**: Adding optional fields, improving error handling, or documentation updates.

**Deprecation Policy**: Deprecated fields must remain supported for at least one major version with warning messages.
