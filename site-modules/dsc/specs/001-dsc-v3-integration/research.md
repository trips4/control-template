# Research: Puppet-DSC V3 Integration

**Feature**: 001-dsc-v3-integration  
**Phase**: 0 - Research & Design Decisions  
**Date**: 2025-11-10

---

## Research Questions

### 1. DSC V3 CLI Interface and Command Structure

**Question**: What is the exact command structure for `dsc config set` and its input/output formats?

**Research Source**: [Microsoft DSC V3 Documentation - config set command](https://learn.microsoft.com/en-us/powershell/dsc/reference/cli/config/set?view=dsc-3.0)

**Findings**:

**Command Syntax**:
```bash
dsc config set [OPTIONS]
```

**Binary Location**:
- **Windows**: `C:\Windows\DSC\dsc.exe`
- **Linux/macOS/Other**: `/opt/DSC/dsc`
- **Note**: Hardcoded paths for initial release, configurable in future versions

**Key Options**:
- `--document <PATH>` or stdin: YAML/JSON configuration document
- `--format <yaml|json>`: Input format (default: auto-detect)
- `--output-format <json|yaml>`: Output format (default: json)
- `--what-if`: Simulate changes without applying (noop mode)

**Input Format** (YAML):
```yaml
$schema: https://raw.githubusercontent.com/PowerShell/DSC/main/schemas/2024/04/config/document.json
resources:
  - name: resource_instance_name
    type: ModuleName/ResourceType
    properties:
      property1: value1
      property2: value2
```

**Input Format** (with adapter):
```yaml
resources:
  - name: resource_instance_name
    type: ModuleName/ResourceType
    adapter: AdapterName
    properties:
      property1: value1
```

**Output Format** (JSON):
```json
{
  "results": [
    {
      "name": "resource_instance_name",
      "type": "ModuleName/ResourceType",
      "result": {
        "beforeState": { ... },
        "afterState": { ... },
        "changedProperties": ["property1"]
      }
    }
  ],
  "messages": [],
  "hadErrors": false
}
```

**Decision**: 
- Use YAML for DSC input (easier to generate from Puppet hash than JSON)
- Parse JSON output from DSC (structured, easier error detection)
- Map `--what-if` to Puppet noop mode
- Pass input via stdin to avoid file management

**Rationale**: 
- YAML is more forgiving for string escaping and multi-line values
- JSON output is structured and includes explicit error indicators
- stdin avoids temp file cleanup and race conditions
- `--what-if` directly maps to Puppet's noop semantics

---

### 2. pwshlib Integration Patterns

**Question**: How does puppetlabs/pwshlib execute PowerShell commands and return results?

**Research Source**: [puppetlabs/pwshlib Forge documentation](https://forge.puppet.com/modules/puppetlabs/pwshlib/readme)

**Findings**:

**Module Purpose**: Provides Ruby classes to manage PowerShell sessions and execute PowerShell code from Puppet providers.

**Key Classes**:
- `Pwsh::Manager`: Manages PowerShell process lifecycle
- `Pwsh::Util`: Utility methods for executing PowerShell commands

**Usage Pattern**:
```ruby
require 'ruby-pwsh'

# Initialize PowerShell manager (reuses sessions)
ps_manager = Pwsh::Manager.instance('dsc_resource')

# Execute PowerShell command
result = ps_manager.execute('Get-Command dsc')

# Access results
result[:stdout]  # Standard output
result[:stderr]  # Error output  
result[:exitcode] # Exit code
```

**Session Management**:
- Manager maintains persistent PowerShell session per provider instance
- Reduces overhead of spawning new PowerShell processes
- Automatically detects PowerShell 7+ availability

**Decision**: 
- Use `Pwsh::Manager.instance('dsc_provider')` for session management
- Execute DSC commands via `ps_manager.execute()` with platform-specific binary path
- Binary paths (hardcoded for initial release):
  - Windows: `C:\Windows\DSC\dsc.exe`
  - Linux/macOS/Other: `/opt/DSC/dsc`
- Pipe YAML input via stdin using PowerShell's `$input` variable
- Parse stdout as JSON using Ruby's `JSON.parse()`

**Rationale**:
- Persistent sessions reduce per-resource overhead
- pwshlib handles PowerShell availability detection
- Hardcoded paths simplify initial implementation (configurable in future)
- stdin piping supported natively by pwshlib
- JSON parsing is standard Ruby library functionality

---

### 3. Puppet Type and Provider Architecture

**Question**: What is the optimal structure for a custom Puppet type with a single provider?

**Research Source**: Puppet development best practices and PDK conventions

**Findings**:

**Type Definition** (`lib/puppet/type/dsc_resource.rb`):
- Defines parameters: `name`, `type`, `input`, `adapter`
- Validates parameter types using Puppet data types
- No business logic (pure declaration)

**Parameter Design**:
```ruby
Puppet::Type.newtype(:dsc_resource) do
  @doc = "Manages DSC V3 resources via dsc config set"
  
  ensurable  # Adds ensure property (present/absent)
  
  newparam(:name, namevar: true) do
    desc "Resource instance name"
  end
  
  newparam(:type) do
    desc "DSC resource type (e.g., Microsoft.Windows/Registry)"
    validate do |value|
      raise ArgumentError, "type must be a string" unless value.is_a?(String)
      raise ArgumentError, "type must contain a /" unless value.include?('/')
    end
  end
  
  newparam(:input) do
    desc "DSC resource properties as a hash"
    validate do |value|
      raise ArgumentError, "input must be a hash" unless value.is_a?(Hash)
    end
  end
  
  newparam(:adapter) do
    desc "Optional DSC adapter name"
  end
end
```

**Provider Implementation** (`lib/puppet/provider/dsc_resource/dsc.rb`):
- Implements `exists?`, `create`, `destroy` methods
- Handles DSC command execution and output parsing
- Reports property changes back to Puppet

**Provider Pattern**:
```ruby
Puppet::Type.type(:dsc_resource).provide(:dsc) do
  desc "Manages DSC V3 resources"
  
  confine operatingsystem: [:windows, :ubuntu, :redhat, :darwin]
  confine feature: :powershell
  
  def exists?
    # Use dsc config test to check current state
  end
  
  def create
    # Use dsc config set to apply configuration
  end
  
  def destroy
    # Use dsc config set with ensure: absent
  end
end
```

**Decision**:
- Use ensurable type (provides `ensure => present/absent`)
- Three parameters: `type` (required), `input` (required), `adapter` (optional)
- Single provider named `dsc` (no need for multiple providers)
- Implement `exists?` using `dsc config test`, `create/destroy` using `dsc config set`

**Rationale**:
- ensurable is Puppet idiom for resource existence
- Explicit parameter validation catches errors early
- Single provider sufficient (DSC V3 works identically across platforms)
- test/set pattern aligns with Puppet's idempotency model

---

### 4. Idempotency and State Management

**Question**: How do we ensure idempotent behavior and correctly detect when changes are needed?

**Findings**:

**DSC V3 Test Operation**:
```bash
dsc config test --document <config.yaml>
```

Output includes `inDesiredState` boolean for each resource.

**DSC V3 Set Operation**:
```bash
dsc config set --document <config.yaml>
```

Output includes `beforeState`, `afterState`, and `changedProperties`.

**Puppet Provider Lifecycle**:
1. Puppet calls `exists?` to check if resource exists
2. If not exists or out of sync, calls `create` or `destroy`
3. Provider reports changes via `@property_flush` or return values

**Decision**:
- Implement `exists?` by running `dsc config test`
  - Return `true` if `inDesiredState: true`
  - Return `false` if `inDesiredState: false` or resource missing
- Implement `create` by running `dsc config set`
  - Parse `changedProperties` to report changes to Puppet
  - Set resource as changed if `changedProperties` is non-empty
- Implement noop by passing `--what-if` flag to DSC
  - Report what would change without applying

**Rationale**:
- DSC's test/set pattern maps perfectly to Puppet's exists?/create pattern
- `changedProperties` provides explicit change reporting
- `--what-if` eliminates need for custom noop logic

---

### 5. Error Handling and Reporting

**Question**: How do we translate DSC errors into Puppet-friendly error messages?

**Findings**:

**DSC Error Indicators**:
- `hadErrors: true` in JSON output
- `messages` array contains error details
- Non-zero exit code from `dsc` command

**Error Scenarios**:
1. **DSC module not found**: `"type 'Foo/Bar' not found"`
2. **Property validation failed**: `"property 'x' must be..."`
3. **Resource execution failed**: `"Set operation failed: ..."`
4. **PowerShell not available**: pwshlib raises exception
5. **DSC not installed**: `dsc: command not found`

**Decision**:
- Check for `hadErrors: true` in DSC output
- If errors present, extract messages and raise Puppet::Error
- Prefix errors with context: `"DSC resource 'name' failed: <message>"`
- Catch pwshlib exceptions and re-raise with helpful message
- Pre-flight check: verify `dsc` command exists in PowerShell session

**Rationale**:
- Clear error messages reduce troubleshooting time
- Context (resource name, operation) helps identify which resource failed
- Pre-flight checks catch environment issues before resource application

---

### 6. YAML Generation from Puppet Hash

**Question**: How do we convert Puppet's `input` hash parameter to valid DSC YAML?

**Findings**:

**Puppet Hash Structure**:
```puppet
dsc_resource { 'example':
  type  => 'Microsoft.Windows/Registry',
  input => {
    keyPath   => 'HKLM:\Software\MyApp',
    valueName => 'Version',
    valueData => '1.0.0',
  },
}
```

**Required DSC YAML**:
```yaml
$schema: https://raw.githubusercontent.com/PowerShell/DSC/main/schemas/2024/04/config/document.json
resources:
  - name: example
    type: Microsoft.Windows/Registry
    properties:
      keyPath: 'HKLM:\Software\MyApp'
      valueName: Version
      valueData: 1.0.0
```

**Ruby YAML Generation**:
```ruby
require 'yaml'

def generate_dsc_yaml
  config = {
    '$schema' => 'https://raw.githubusercontent.com/PowerShell/DSC/main/schemas/2024/04/config/document.json',
    'resources' => [
      {
        'name' => resource[:name],
        'type' => resource[:type],
        'properties' => resource[:input]
      }
    ]
  }
  
  # Add adapter if specified
  config['resources'][0]['adapter'] = resource[:adapter] if resource[:adapter]
  
  config.to_yaml
end
```

**Decision**:
- Use Ruby's built-in `YAML` library
- Construct hash matching DSC schema structure
- Convert using `to_yaml` method
- Handle adapter as optional field

**Rationale**:
- Ruby's YAML library handles escaping and formatting
- Hash construction allows dynamic adapter inclusion
- Schema URL required for DSC validation

---

### 7. Cross-Platform Testing Strategy

**Question**: How do we test across Windows, Linux, and macOS without requiring all platforms for development?

**Findings**:

**PDK Testing Capabilities**:
- `pdk test unit`: Runs rspec-puppet tests (platform-agnostic)
- `pdk test acceptance`: Runs acceptance tests (requires target platforms)

**Acceptance Testing Approaches**:
1. **Local VMs**: Vagrant with multiple OS boxes
2. **CI/CD**: GitHub Actions with matrix strategy (windows-latest, ubuntu-latest, macos-latest)
3. **Docker**: Limited (macOS unsupported, Windows requires specific images)

**Decision**:
- **Unit tests**: Mock pwshlib responses, test YAML generation and JSON parsing logic
- **Acceptance tests**: Use GitHub Actions matrix for actual DSC execution
  - Windows runner: Test Microsoft.Windows resources
  - Ubuntu runner: Test cross-platform resources
  - macOS runner: Test macOS-specific scenarios
- **Local development**: Unit tests only, acceptance tests run in CI

**Rationale**:
- Unit tests provide fast feedback without platform dependencies
- GitHub Actions provides free multi-platform runners
- Mocking pwshlib allows testing provider logic without PowerShell
- CI-based acceptance tests catch platform-specific issues before release

---

### 8. Noop Mode Implementation

**Question**: How do we implement Puppet's noop mode for DSC resources?

**Findings**:

**Puppet Noop Semantics**:
- When `noop => true`, resources report what would change without applying
- Providers access noop state via `resource.noop?` or `Puppet[:noop]`

**DSC What-If Mode**:
- `dsc config set --what-if` simulates changes without applying
- Output format identical to normal set operation
- `changedProperties` still populated with what would change

**Decision**:
- In `create` method, check if `resource.noop?` is true
- If noop, append `--what-if` flag to `dsc config set` command
- Parse output identically (DSC provides same change information)
- Report changes to Puppet as if they would be applied

**Implementation**:
```ruby
def create
  yaml_input = generate_dsc_yaml
  
  cmd = 'dsc config set --format yaml --output-format json'
  cmd += ' --what-if' if resource.noop?
  
  result = execute_dsc_command(cmd, yaml_input)
  parse_and_report_changes(result)
end
```

**Rationale**:
- DSC's `--what-if` is designed exactly for this use case
- No custom logic needed to simulate changes
- Consistent reporting between noop and normal mode

---

### 9. DSC Binary Location Strategy

**Question**: How do we locate the DSC executable across different platforms?

**Findings**:

**Platform-Specific Paths**:
- **Windows**: `C:\Windows\DSC\dsc.exe`
- **Linux**: `/opt/DSC/dsc`
- **macOS**: `/opt/DSC/dsc`
- **Other Unix**: `/opt/DSC/dsc`

**Decision**:
- Hardcode binary paths for initial release (v1.0)
- Use platform detection via Ruby's `Facter.value(:kernel)` or `RUBY_PLATFORM`
- Map kernel to binary path:
  ```ruby
  def dsc_binary_path
    case Facter.value(:kernel)
    when 'windows'
      'C:\Windows\DSC\dsc.exe'
    else
      '/opt/DSC/dsc'
    end
  end
  ```
- Future enhancement: Make path configurable via module parameter or environment variable

**Rationale**:
- Standardized installation paths simplify deployment and troubleshooting
- Hardcoded paths avoid configuration complexity for initial release
- Platform detection is reliable via Puppet's Facter
- Users expect DSC to be installed in system directories
- Future configurability allows custom installations without breaking existing deployments

**Trade-offs Accepted**:
- Requires DSC to be installed in specific locations (documented in README)
- No support for custom install paths in v1.0 (future enhancement tracked)
- Users with non-standard installations must create symlinks or wait for configurable version

---

## Technology Stack Decisions

### Language and Runtime
- **Ruby**: 2.7+ (Puppet Agent 8.x requirement)
- **PowerShell**: 7.2+ (required on managed nodes, not bundled)

### Dependencies
- **puppetlabs/pwshlib**: >= 1.0.0 (PowerShell execution)
- **ruby-pwsh gem**: Provided by pwshlib, handles PS session management
- **Ruby stdlib**: YAML, JSON libraries for data transformation

### Testing Stack
- **rspec-puppet**: Puppet resource testing
- **rspec**: Ruby unit testing
- **PDK**: Test orchestration and validation
- **GitHub Actions**: Multi-platform acceptance testing

### Development Tools
- **PDK**: 3.4.0+ (module scaffolding, validation, testing)
- **Puppet Strings**: Documentation generation
- **RuboCop**: Ruby style enforcement
- **puppet-lint**: Puppet manifest linting

---

## Design Patterns

### Provider Pattern: Adapter
- Provider acts as adapter between Puppet DSL and DSC CLI
- Translates Puppet hash to YAML, DSC JSON to Puppet events
- Isolates DSC-specific logic from Puppet catalog compilation

### Error Handling Pattern: Fail Fast
- Pre-flight checks for PowerShell and DSC availability
- Immediate failure with actionable error messages
- No silent failures or degraded modes

### Session Management Pattern: Singleton
- One PowerShell session per Puppet agent run (via pwshlib)
- Reduces overhead of spawning multiple PowerShell processes
- Session automatically cleaned up by pwshlib at run end

### Testing Pattern: Mock External Dependencies
- Unit tests mock pwshlib responses
- Unit tests don't require PowerShell or DSC
- Acceptance tests run real DSC commands on CI

---

## Open Questions Resolved

All technical clarifications have been researched and documented above. No remaining open questions.

---

**Phase 0 Complete**: Ready to proceed to Phase 1 (Data Model and Contracts)
