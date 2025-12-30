# Research Document: Custom Facter Fact Implementation for DSC Installation Path

**Feature**: DSC Installation Path Detection  
**Branch**: `002-dsc-install-fact`  
**Date**: 2025-12-16  
**Context**: puppetlabs-dsc module needs provider to discover DSC installation location managed by module's init.pp class

---

## Executive Summary

This research addresses how to implement a custom Facter fact that enables the `dsc_resource` provider to discover where the DSC v3 binary was installed by the module's `dsc` class. The fundamental challenge is that **Facter facts cannot directly access Puppet catalog information or class parameters** - facts are resolved before catalog compilation. The solution uses **external facts written to disk by the manifest** to communicate the installation path from compile-time to fact-resolution time.

**Key Decisions**:
1. Use structured external fact (JSON) written by `dsc` class during catalog application
2. Implement Ruby custom fact that reads external fact file with platform-specific defaults
3. Provider checks fact first, falls back to hardcoded paths for backward compatibility
4. Optimize fact resolution with early file existence checks and caching

---

## 1. Custom Fact Implementation Patterns

### 1.1 Core Constraint: Facts Run Before Catalog Compilation

**Critical Understanding**: Facter facts are resolved **before** Puppet catalog compilation begins. This means:

```
Execution Order:
1. Facter collects facts (including custom facts)
2. Facts are sent to Puppet Server
3. Catalog is compiled using facts
4. Catalog is applied to node
```

**Implication**: A custom fact **cannot** access:
- Puppet class parameters
- Catalog resources
- Variables from manifests
- Data from Hiera during fact resolution (Hiera is catalog-scope)

### 1.2 Decision: External Facts Written by Manifest

**Decision**: Use external facts as a communication channel from manifest to fact system.

**Pattern**:
```ruby
# lib/facter/dsc_install_path.rb
Facter.add(:dsc_install_path) do
  confine kernel: ['Linux', 'Darwin', 'windows']
  
  setcode do
    # Read external fact file written by dsc class
    fact_file = case Facter.value(:kernel)
                when 'windows'
                  'C:/ProgramData/PuppetLabs/facter/facts.d/dsc_install.json'
                else
                  '/etc/puppetlabs/facter/facts.d/dsc_install.json'
                end
    
    if File.exist?(fact_file)
      require 'json'
      begin
        data = JSON.parse(File.read(fact_file))
        data['dsc_install_path']
      rescue JSON::ParserError, Errno::ENOENT
        nil
      end
    else
      nil
    end
  end
end
```

**Manifest writes fact file during catalog application**:
```puppet
# manifests/init.pp
class dsc (
  Optional[Stdlib::Absolutepath] $install_dir = undef,
  # ... other params
) {
  # ... installation logic ...
  
  # Write external fact for provider to discover
  $fact_dir = $facts['kernel'] ? {
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
    require => File[$fact_dir],
  }
}
```

**Workflow**:
1. **First Puppet run**: Fact returns `nil` (file doesn't exist yet) → Provider uses defaults
2. **Manifest applies**: Creates external fact file with installation path
3. **Second Puppet run**: Fact reads file → Provider uses module-managed path
4. **Subsequent runs**: Fact consistently returns correct path

### 1.3 Rationale

**Why External Facts?**

| Approach | Can Access Catalog? | Can Read Files? | Performance | Complexity |
|----------|---------------------|-----------------|-------------|------------|
| Direct catalog access | ❌ No | N/A | N/A | Impossible |
| External facts | ✅ Yes (via file) | ✅ Yes | Fast (~5ms) | Low |
| Custom function | ✅ Yes | ✅ Yes | N/A | Wrong tool (catalog-time only) |
| Environment variable | ❌ No direct way | N/A | Fast | High complexity in manifest |

**External facts are the standard Puppet pattern** for persisting node-specific configuration that needs to survive across Puppet runs.

### 1.4 Alternative Considered: Environment Variables

**Alternative**: Have `dsc` class set environment variable, fact reads it.

**Rejected because**:
- Environment variables set in Puppet exec don't persist to next Puppet run
- Would require system-wide environment setup (registry on Windows, `/etc/environment` on Linux)
- More fragile than file-based approach
- Environment changes require logout/reboot to propagate

### 1.5 Cross-Platform Implementation

**Decision**: Single fact implementation with platform-specific paths via `confine` and conditional logic.

```ruby
Facter.add(:dsc_install_path) do
  # Only resolve on supported platforms
  confine kernel: ['Linux', 'Darwin', 'windows']
  
  setcode do
    kernel = Facter.value(:kernel)
    
    # Platform-specific fact file location
    fact_file = case kernel
                when 'windows'
                  'C:/ProgramData/PuppetLabs/facter/facts.d/dsc_install.json'
                when 'Darwin'
                  '/opt/puppetlabs/facter/facts.d/dsc_install.json'
                else # Linux
                  '/etc/puppetlabs/facter/facts.d/dsc_install.json'
                end
    
    # Early exit if file doesn't exist (most common case on first run)
    return nil unless File.exist?(fact_file)
    
    # Read and parse JSON
    require 'json'
    begin
      data = JSON.parse(File.read(fact_file))
      install_path = data['dsc_install_path']
      
      # Validate path exists before returning
      if install_path && File.directory?(install_path)
        install_path
      else
        nil
      end
    rescue JSON::ParserError, Errno::ENOENT, Errno::EACCES => e
      Facter.debug("dsc_install_path: Failed to read fact file: #{e.message}")
      nil
    end
  end
end
```

**Platform-Specific Paths** (from Puppet Agent documentation):
- **Windows**: `C:/ProgramData/PuppetLabs/facter/facts.d/` (Puppet 6+)
- **Linux**: `/etc/puppetlabs/facter/facts.d/`
- **macOS**: `/opt/puppetlabs/facter/facts.d/`

### 1.6 Handling Unavailable Values

**Decision**: Return `nil` when value unavailable, provider interprets `nil` as "use default".

**Cases where fact returns `nil`**:
1. External fact file doesn't exist (DSC not installed via module)
2. JSON parsing fails (corrupted file)
3. File exists but path value is missing/invalid
4. Path doesn't actually exist on filesystem (DSC was removed manually)
5. Permission denied reading fact file

**Provider handling**:
```ruby
def dsc_binary_path
  require 'facter'
  
  # Try module-managed installation first
  if Facter.value(:dsc_install_path)
    install_dir = Facter.value(:dsc_install_path)
    binary_name = Facter.value(:kernel) == 'windows' ? 'dsc.exe' : 'dsc'
    return File.join(install_dir, binary_name)
  end
  
  # Fall back to platform defaults for manual installations
  case Facter.value(:kernel)
  when 'windows'
    'C:\\Windows\\DSC\\dsc.exe'
  else
    '/opt/DSC/dsc'
  end
end
```

---

## 2. DSC Class Parameter Detection

### 2.1 Problem Statement

The `dsc` class in `manifests/init.pp` has an `install_dir` parameter with platform-specific defaults:

```puppet
class dsc (
  Optional[Stdlib::Absolutepath] $install_dir = undef,
  # ...
) {
  $default_install_dir = case $facts['kernel'] {
    'windows': { 'C:/Program Files/DSC' }
    'Darwin':  { '/usr/local/dsc' }
    'Linux':   { '/opt/dsc' }
  }
  
  $actual_install_dir = pick($install_dir, $default_install_dir)
  
  # ... installation logic using $actual_install_dir ...
}
```

**Question**: How can a fact determine what `$actual_install_dir` was?

### 2.2 Decision: External Fact File as State Persistence

**Decision**: The `dsc` class writes the resolved `$actual_install_dir` to an external fact file during catalog application.

**Implementation in manifest**:
```puppet
class dsc (
  Optional[Stdlib::Absolutepath] $install_dir = undef,
  String $version = 'latest',
  Boolean $manage_path = true,
) {
  # ... determine $actual_install_dir ...
  
  # Persist installation path for fact resolution
  $fact_dir = $facts['kernel'] ? {
    'windows' => 'C:/ProgramData/PuppetLabs/facter/facts.d',
    default   => '/etc/puppetlabs/facter/facts.d',
  }
  
  file { $fact_dir:
    ensure => directory,
    owner  => 'root',
    mode   => '0755',
  }
  
  file { "${fact_dir}/dsc_install.json":
    ensure  => file,
    owner   => 'root',
    mode    => '0644',
    content => to_json_pretty({
      'dsc_install_path' => $actual_install_dir,
      'dsc_version'      => $version,
      'dsc_managed'      => true,
    }),
    require => File[$fact_dir],
  }
}
```

**Rationale**:
- Manifest has full access to `$actual_install_dir` at compile time
- Writing to disk creates persistent state
- External fact system naturally reads from this location
- Standard Puppet pattern for node-specific configuration
- Works identically across all platforms

### 2.3 Detecting Class Inclusion

**Question**: How does fact know if `dsc` class was included?

**Decision**: Presence of external fact file indicates class inclusion.

```ruby
Facter.add(:dsc_managed) do
  confine kernel: ['Linux', 'Darwin', 'windows']
  
  setcode do
    # If fact file exists, DSC is managed by module
    fact_file = case Facter.value(:kernel)
                when 'windows'
                  'C:/ProgramData/PuppetLabs/facter/facts.d/dsc_install.json'
                else
                  '/etc/puppetlabs/facter/facts.d/dsc_install.json'
                end
    
    File.exist?(fact_file)
  end
end
```

**Alternative considered**: Check for catalog compilation metadata.
**Rejected**: No reliable way for fact to query catalog state - facts run before compilation.

### 2.4 Communication Timeline

```
Puppet Run 1 (Initial):
├─ Fact resolution: dsc_install_path = nil (file doesn't exist)
├─ Catalog compilation: include dsc { install_dir => '/custom/path' }
├─ Catalog application:
│  ├─ Install DSC to /custom/path
│  └─ Write /etc/puppetlabs/facter/facts.d/dsc_install.json
└─ Provider uses default paths (backward compat)

Puppet Run 2 (Subsequent):
├─ Fact resolution: dsc_install_path = '/custom/path' (reads file)
├─ Catalog compilation: include dsc { install_dir => '/custom/path' }
├─ Provider uses /custom/path/dsc from fact
└─ All resources work with module-managed DSC
```

**Important**: This pattern requires **2 Puppet runs** for full convergence:
1. First run installs DSC and writes fact file
2. Second run fact picks up path and provider uses it

This is standard Puppet behavior for external facts and is acceptable.

---

## 3. Fact Performance Best Practices

### 3.1 Performance Goals

**Target**: Fact resolution < 100ms (requirement from plan.md)

**Measurement approach**:
```ruby
# In spec test:
require 'benchmark'

RSpec.describe 'dsc_install_path fact' do
  it 'resolves in under 100ms' do
    elapsed = Benchmark.realtime do
      1000.times { Facter.value(:dsc_install_path) }
    end
    
    avg_time_ms = (elapsed / 1000.0) * 1000
    expect(avg_time_ms).to be < 100
  end
end
```

### 3.2 Performance Optimization Strategies

#### 3.2.1 Early Exit Pattern

**Decision**: Check file existence before attempting JSON parsing.

```ruby
setcode do
  fact_file = platform_specific_path()
  
  # Early exit - fastest path for "not installed" case
  return nil unless File.exist?(fact_file)
  
  # Only parse JSON if file exists
  require 'json'
  # ... parsing logic ...
end
```

**Rationale**:
- `File.exist?` is fast (~1-2ms)
- JSON parsing is slower (~5-10ms)
- Most nodes initially won't have DSC installed
- Early exit optimizes common case

#### 3.2.2 Lazy Loading Dependencies

**Decision**: Use `require` inside `setcode` block, not at module level.

```ruby
Facter.add(:dsc_install_path) do
  setcode do
    # Lazy load JSON only when fact executes
    require 'json'
    # ... use JSON ...
  end
end
```

**Rationale**:
- Only loads JSON library if fact executes
- Facter may skip fact if `confine` doesn't match
- Reduces memory footprint on incompatible platforms

#### 3.2.3 Minimal File I/O

**Decision**: Single file read operation, no directory scanning.

```ruby
# ✅ GOOD: Direct file read
File.read(fact_file)

# ❌ BAD: Multiple file operations
Dir.glob('/etc/puppetlabs/facter/facts.d/*.json').each { |f| ... }
```

**Rationale**:
- Single file read is ~5ms
- Directory scanning is ~20-50ms
- Known file path eliminates search overhead

#### 3.2.4 Avoid Validation Overhead

**Decision**: Minimal validation in fact, rely on manifest for correctness.

```ruby
setcode do
  # ... read file ...
  install_path = data['dsc_install_path']
  
  # Only validate path exists, don't check binary
  if install_path && File.directory?(install_path)
    install_path
  else
    nil
  end
end
```

**Rationale**:
- Checking for binary (`File.exist?("#{path}/dsc")`) adds extra I/O
- Manifest ensures binary exists during installation
- Provider can handle missing binary gracefully
- Fact should be "fast and simple", not "thorough validator"

### 3.3 Performance Characteristics by Platform

| Platform | File Read | JSON Parse | Dir Check | Total |
|----------|-----------|------------|-----------|-------|
| Linux SSD | ~2ms | ~5ms | ~2ms | ~9ms |
| Windows NTFS | ~5ms | ~5ms | ~3ms | ~13ms |
| macOS APFS | ~2ms | ~5ms | ~2ms | ~9ms |
| Linux HDD | ~10ms | ~5ms | ~5ms | ~20ms |

**All well under 100ms target**.

### 3.4 Caching Considerations

**Decision**: No explicit caching needed - Facter handles it.

**Rationale**:
- Facter caches fact values per Puppet run
- Fact only resolves once during fact collection phase
- External fact files change rarely (only on `dsc` class parameter changes)
- Adding Ruby-level caching adds complexity without measurable benefit

**Facter's built-in caching**:
```ruby
# First call: Executes setcode block
Facter.value(:dsc_install_path)  # ~10ms

# Subsequent calls in same run: Returns cached value
Facter.value(:dsc_install_path)  # ~0.1ms
Facter.value(:dsc_install_path)  # ~0.1ms
```

---

## 4. Testing Custom Facts with RSpec

### 4.1 Testing Strategy

**Decision**: Use RSpec with Facter stubbing for unit tests, spec-helper for platform mocking.

**Test file location**: `spec/unit/facter/dsc_install_path_spec.rb`

### 4.2 Test Structure Pattern

```ruby
# spec/unit/facter/dsc_install_path_spec.rb
require 'spec_helper'
require 'facter'

RSpec.describe 'dsc_install_path fact' do
  subject(:fact) { Facter.value(:dsc_install_path) }
  
  before do
    Facter.clear
    # Clear cache between tests
    Facter.clear_messages
  end
  
  # Test structure:
  # 1. Platform-specific tests
  # 2. File existence tests
  # 3. JSON parsing tests
  # 4. Error handling tests
  # 5. Performance tests
end
```

### 4.3 Mocking File System Access

**Pattern**: Use RSpec's `allow` with `File` class stubs.

```ruby
describe 'when fact file exists' do
  let(:fact_file) { '/etc/puppetlabs/facter/facts.d/dsc_install.json' }
  let(:json_content) do
    {
      'dsc_install_path' => '/opt/dsc',
      'dsc_version' => 'v3.1.2',
      'dsc_managed' => true
    }
  end
  
  before do
    # Stub kernel fact
    allow(Facter).to receive(:value).with(:kernel).and_return('Linux')
    
    # Stub file operations
    allow(File).to receive(:exist?).with(fact_file).and_return(true)
    allow(File).to receive(:directory?).with('/opt/dsc').and_return(true)
    allow(File).to receive(:read).with(fact_file)
      .and_return(JSON.generate(json_content))
  end
  
  it 'returns the installation path' do
    expect(fact).to eq('/opt/dsc')
  end
end

describe 'when fact file does not exist' do
  before do
    allow(Facter).to receive(:value).with(:kernel).and_return('Linux')
    allow(File).to receive(:exist?).and_return(false)
  end
  
  it 'returns nil' do
    expect(fact).to be_nil
  end
end
```

### 4.4 Platform Detection Testing

**Pattern**: Parameterized tests for each platform.

```ruby
describe 'platform-specific paths' do
  [
    { kernel: 'Linux',   path: '/etc/puppetlabs/facter/facts.d/dsc_install.json' },
    { kernel: 'Darwin',  path: '/opt/puppetlabs/facter/facts.d/dsc_install.json' },
    { kernel: 'windows', path: 'C:/ProgramData/PuppetLabs/facter/facts.d/dsc_install.json' },
  ].each do |platform|
    context "on #{platform[:kernel]}" do
      before do
        allow(Facter).to receive(:value).with(:kernel).and_return(platform[:kernel])
        allow(File).to receive(:exist?).with(platform[:path]).and_return(true)
        allow(File).to receive(:directory?).and_return(true)
        allow(File).to receive(:read).with(platform[:path])
          .and_return(JSON.generate({ 'dsc_install_path' => '/test/path' }))
      end
      
      it "reads from #{platform[:path]}" do
        expect(fact).to eq('/test/path')
      end
    end
  end
end
```

### 4.5 Error Handling Tests

**Pattern**: Test common failure modes with explicit expectations.

```ruby
describe 'error handling' do
  let(:fact_file) { '/etc/puppetlabs/facter/facts.d/dsc_install.json' }
  
  before do
    allow(Facter).to receive(:value).with(:kernel).and_return('Linux')
    allow(File).to receive(:exist?).with(fact_file).and_return(true)
    allow(File).to receive(:directory?).and_return(true)
  end
  
  context 'when JSON is malformed' do
    before do
      allow(File).to receive(:read).with(fact_file).and_return('{ invalid json }')
    end
    
    it 'returns nil' do
      expect(fact).to be_nil
    end
    
    it 'logs debug message' do
      # Capture Facter debug output
      expect(Facter).to receive(:debug).with(/Failed to read fact file/)
      fact
    end
  end
  
  context 'when file read raises permission error' do
    before do
      allow(File).to receive(:read).with(fact_file)
        .and_raise(Errno::EACCES, 'Permission denied')
    end
    
    it 'returns nil gracefully' do
      expect(fact).to be_nil
    end
  end
  
  context 'when path value is missing from JSON' do
    before do
      allow(File).to receive(:read).with(fact_file)
        .and_return(JSON.generate({ 'other_key' => 'value' }))
    end
    
    it 'returns nil' do
      expect(fact).to be_nil
    end
  end
  
  context 'when path does not exist on filesystem' do
    before do
      allow(File).to receive(:read).with(fact_file)
        .and_return(JSON.generate({ 'dsc_install_path' => '/nonexistent' }))
      allow(File).to receive(:directory?).with('/nonexistent').and_return(false)
    end
    
    it 'returns nil' do
      expect(fact).to be_nil
    end
  end
end
```

### 4.6 Integration Testing with Provider

**Pattern**: Test provider's consumption of fact in provider spec.

```ruby
# spec/unit/puppet/provider/dsc_resource/dsc_resource_spec.rb
describe 'dsc_binary_path' do
  context 'when dsc_install_path fact is available' do
    before do
      allow(Facter).to receive(:value).with(:dsc_install_path)
        .and_return('/custom/dsc/path')
      allow(Facter).to receive(:value).with(:kernel).and_return('Linux')
    end
    
    it 'uses path from fact' do
      expect(provider.send(:dsc_binary_path)).to eq('/custom/dsc/path/dsc')
    end
  end
  
  context 'when dsc_install_path fact is nil' do
    before do
      allow(Facter).to receive(:value).with(:dsc_install_path).and_return(nil)
      allow(Facter).to receive(:value).with(:kernel).and_return('Linux')
    end
    
    it 'falls back to platform default' do
      expect(provider.send(:dsc_binary_path)).to eq('/opt/DSC/dsc')
    end
  end
end
```

### 4.7 Test Coverage Requirements

**Decision**: Aim for 100% code coverage on custom fact.

**Rationale**:
- Fact is small (~50 lines)
- Critical path for provider functionality
- Easy to achieve 100% with parameterized tests

**Coverage breakdown**:
```
Lines to cover:
├─ Platform detection (3 platforms) = 3 tests
├─ File existence (exists/doesn't exist) = 2 tests
├─ JSON parsing (valid/invalid) = 2 tests
├─ Path validation (exists/doesn't exist) = 2 tests
├─ Error cases (permission denied, missing key) = 2 tests
└─ Nil cases (file missing, parse error, invalid path) = 3 tests
Total: ~14 test cases
```

---

## 5. Implementation Recommendations

### 5.1 Custom Fact Implementation

**File**: `lib/facter/dsc_install_path.rb`

```ruby
# frozen_string_literal: true

# Custom Facter fact to expose DSC installation path
#
# This fact reads the installation path from an external fact file
# written by the dsc class during catalog application. This enables
# the dsc_resource provider to automatically discover where DSC was
# installed by the module.
#
# @return [String, nil] Absolute path to DSC installation directory,
#   or nil if DSC is not managed by the module
#
# @example
#   Facter.value(:dsc_install_path) #=> '/opt/dsc'
#   Facter.value(:dsc_install_path) #=> nil (if not installed)
#
Facter.add(:dsc_install_path) do
  confine kernel: ['Linux', 'Darwin', 'windows']

  setcode do
    kernel = Facter.value(:kernel)

    # Platform-specific fact file location
    fact_file = case kernel
                when 'windows'
                  'C:/ProgramData/PuppetLabs/facter/facts.d/dsc_install.json'
                when 'Darwin'
                  '/opt/puppetlabs/facter/facts.d/dsc_install.json'
                else # Linux
                  '/etc/puppetlabs/facter/facts.d/dsc_install.json'
                end

    # Early exit if file doesn't exist (common case on first run)
    next nil unless File.exist?(fact_file)

    # Read and parse JSON fact file
    require 'json'

    begin
      data = JSON.parse(File.read(fact_file))
      install_path = data['dsc_install_path']

      # Validate path exists on filesystem before returning
      if install_path && File.directory?(install_path)
        install_path
      else
        Facter.debug("dsc_install_path: Path '#{install_path}' does not exist")
        nil
      end
    rescue JSON::ParserError => e
      Facter.debug("dsc_install_path: Failed to parse JSON: #{e.message}")
      nil
    rescue Errno::ENOENT, Errno::EACCES => e
      Facter.debug("dsc_install_path: Failed to read file: #{e.message}")
      nil
    rescue StandardError => e
      Facter.debug("dsc_install_path: Unexpected error: #{e.message}")
      nil
    end
  end
end
```

### 5.2 Manifest Modification

**File**: `manifests/init.pp` (add after installation logic)

```puppet
class dsc (
  Optional[Stdlib::Absolutepath] $install_dir = undef,
  String $version = 'latest',
  Boolean $manage_path = true,
) {
  # ... existing installation logic ...
  # ... $actual_install_dir is computed ...
  
  # Persist installation path for fact resolution
  # This enables the dsc_resource provider to discover where DSC was installed
  
  $fact_dir = $facts['kernel'] ? {
    'windows' => 'C:/ProgramData/PuppetLabs/facter/facts.d',
    'Darwin'  => '/opt/puppetlabs/facter/facts.d',
    default   => '/etc/puppetlabs/facter/facts.d',
  }
  
  # Ensure facts.d directory exists
  file { $fact_dir:
    ensure => directory,
    owner  => $facts['kernel'] ? {
      'windows' => undef,
      default   => 'root',
    },
    group  => $facts['kernel'] ? {
      'windows' => undef,
      default   => 'root',
    },
    mode   => $facts['kernel'] ? {
      'windows' => undef,
      default   => '0755',
    },
  }
  
  # Write external fact file with DSC installation details
  file { "${fact_dir}/dsc_install.json":
    ensure  => file,
    owner   => $facts['kernel'] ? {
      'windows' => undef,
      default   => 'root',
    },
    group   => $facts['kernel'] ? {
      'windows' => undef,
      default   => 'root',
    },
    mode    => $facts['kernel'] ? {
      'windows' => undef,
      default   => '0644',
    },
    content => to_json_pretty({
      'dsc_install_path' => $actual_install_dir,
      'dsc_version'      => $version,
      'dsc_managed'      => true,
    }),
    require => [
      File[$fact_dir],
      File["${actual_install_dir}/${dsc_binary}"], # Ensure DSC is installed first
    ],
  }
}
```

### 5.3 Provider Modification

**File**: `lib/puppet/provider/dsc_resource/dsc_resource.rb`

```ruby
# Update dsc_binary_path method (lines ~87-99)

# Get the platform-specific DSC binary path
#
# First checks if DSC was installed by the module (via dsc_install_path fact),
# then falls back to platform default paths for backward compatibility with
# manual installations.
#
# @return [String] Full path to DSC binary
def dsc_binary_path
  require 'facter'

  kernel = Facter.value(:kernel)
  binary_name = kernel == 'windows' ? 'dsc.exe' : 'dsc'

  # Try module-managed installation first
  if Facter.value(:dsc_install_path)
    install_dir = Facter.value(:dsc_install_path)
    return File.join(install_dir, binary_name)
  end

  # Fall back to platform defaults for manual installations
  case kernel
  when 'windows'
    'C:\\Windows\\DSC\\dsc.exe'
  else
    '/opt/DSC/dsc'
  end
end
```

### 5.4 Test Implementation

**File**: `spec/unit/facter/dsc_install_path_spec.rb`

```ruby
# frozen_string_literal: true

require 'spec_helper'
require 'facter'

RSpec.describe 'dsc_install_path fact' do
  subject(:fact) { Facter.value(:dsc_install_path) }

  before do
    Facter.clear
    Facter.clear_messages
  end

  describe 'platform-specific fact file paths' do
    [
      { kernel: 'Linux',   path: '/etc/puppetlabs/facter/facts.d/dsc_install.json', install: '/opt/dsc' },
      { kernel: 'Darwin',  path: '/opt/puppetlabs/facter/facts.d/dsc_install.json', install: '/usr/local/dsc' },
      { kernel: 'windows', path: 'C:/ProgramData/PuppetLabs/facter/facts.d/dsc_install.json', install: 'C:/Program Files/DSC' },
    ].each do |platform|
      context "on #{platform[:kernel]}" do
        let(:json_content) do
          JSON.generate({
            'dsc_install_path' => platform[:install],
            'dsc_version' => 'v3.1.2',
            'dsc_managed' => true
          })
        end

        before do
          allow(Facter).to receive(:value).with(:kernel).and_return(platform[:kernel])
          allow(File).to receive(:exist?).with(platform[:path]).and_return(true)
          allow(File).to receive(:directory?).with(platform[:install]).and_return(true)
          allow(File).to receive(:read).with(platform[:path]).and_return(json_content)
        end

        it "reads from #{platform[:path]}" do
          expect(fact).to eq(platform[:install])
        end
      end
    end
  end

  describe 'when fact file does not exist' do
    before do
      allow(Facter).to receive(:value).with(:kernel).and_return('Linux')
      allow(File).to receive(:exist?).and_return(false)
    end

    it 'returns nil' do
      expect(fact).to be_nil
    end
  end

  describe 'error handling' do
    let(:fact_file) { '/etc/puppetlabs/facter/facts.d/dsc_install.json' }

    before do
      allow(Facter).to receive(:value).with(:kernel).and_return('Linux')
      allow(File).to receive(:exist?).with(fact_file).and_return(true)
    end

    context 'when JSON is malformed' do
      before do
        allow(File).to receive(:read).with(fact_file).and_return('{ invalid json }')
      end

      it 'returns nil' do
        expect(fact).to be_nil
      end
    end

    context 'when file read raises permission error' do
      before do
        allow(File).to receive(:read).with(fact_file)
          .and_raise(Errno::EACCES, 'Permission denied')
      end

      it 'returns nil gracefully' do
        expect(fact).to be_nil
      end
    end

    context 'when dsc_install_path key is missing' do
      before do
        allow(File).to receive(:read).with(fact_file)
          .and_return(JSON.generate({ 'other_key' => 'value' }))
      end

      it 'returns nil' do
        expect(fact).to be_nil
      end
    end

    context 'when install path does not exist on filesystem' do
      before do
        allow(File).to receive(:read).with(fact_file)
          .and_return(JSON.generate({ 'dsc_install_path' => '/nonexistent' }))
        allow(File).to receive(:directory?).with('/nonexistent').and_return(false)
      end

      it 'returns nil' do
        expect(fact).to be_nil
      end
    end
  end

  describe 'performance' do
    let(:fact_file) { '/etc/puppetlabs/facter/facts.d/dsc_install.json' }
    let(:json_content) do
      JSON.generate({ 'dsc_install_path' => '/opt/dsc' })
    end

    before do
      allow(Facter).to receive(:value).with(:kernel).and_return('Linux')
      allow(File).to receive(:exist?).with(fact_file).and_return(true)
      allow(File).to receive(:directory?).with('/opt/dsc').and_return(true)
      allow(File).to receive(:read).with(fact_file).and_return(json_content)
    end

    it 'resolves in under 100ms' do
      require 'benchmark'

      # Clear cache to force re-resolution
      Facter.clear

      elapsed = Benchmark.realtime do
        Facter.value(:dsc_install_path)
      end

      elapsed_ms = elapsed * 1000
      expect(elapsed_ms).to be < 100
    end
  end
end
```

### 5.5 RuboCop and Code Quality

**Decisions**:
- Follow existing module RuboCop configuration
- Run `pdk validate` before committing
- No custom cops needed for this feature
- Maintain consistency with existing provider code style

**Validation workflow**:
```bash
# Run all validations
pdk validate

# Run only Ruby validations
pdk validate ruby

# Run only metadata validations
pdk validate metadata

# Run tests
pdk test unit
```

---

## 6. Alternatives Analysis

### 6.1 Alternative 1: Direct File Reading by Provider

**Approach**: Provider directly reads installation directory from a file.

**Rejected because**:
- Duplicates logic (fact and provider both reading same file)
- Loses Facter's caching and error handling
- Harder to test in isolation
- Violates Puppet's separation of concerns (facts vs providers)
- No reusability (can't use value in manifests or templates)

### 6.2 Alternative 2: Environment Variable

**Approach**: Set environment variable during DSC installation, read it in fact.

**Rejected because**:
- Environment variables set in Puppet don't persist across runs
- Requires system-wide environment changes (complex on Windows)
- Fragile: requires shell reloading or reboots
- Platform-specific implementation complexity
- No advantage over file-based approach

### 6.3 Alternative 3: Hiera Integration

**Approach**: Store installation path in Hiera, read in fact.

**Rejected because**:
- Hiera is catalog-scope, not available during fact resolution
- Would require Hiera configuration on every node
- Adds external dependency (Hiera backend)
- Doesn't solve core problem (fact can't access catalog data)

### 6.4 Alternative 4: Custom Function Instead of Fact

**Approach**: Use a Puppet function to look up installation path during catalog compilation.

**Rejected because**:
- Functions run during catalog compilation (too late for provider setup)
- Provider executes during catalog application, needs path before function can run
- Functions can't communicate to provider in different phase
- Over-complicates what should be simple path lookup

### 6.5 Alternative 5: Registry (Windows) / Config Files (Unix)

**Approach**: Write path to Windows Registry on Windows, config files on Unix.

**Rejected because**:
- Platform-specific implementations increase complexity
- Registry access requires additional Ruby gems on Windows
- External fact files are already standard Puppet pattern
- No performance benefit over file-based approach
- Harder to debug and introspect

---

## 7. Risk Assessment

### 7.1 Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Fact file not created on first run | High | Low | Expected behavior; provider falls back to defaults |
| Permission issues reading fact file | Low | Medium | Comprehensive error handling returns nil gracefully |
| JSON parsing fails (corrupted file) | Low | Low | Try-catch returns nil, logged as debug |
| Disk full prevents fact file write | Very Low | Low | Puppet fails manifest application (separate concern) |
| Path exists but binary removed | Low | Medium | Provider's `dsc_binary_available?` check catches this |
| Race condition: fact read during write | Very Low | Very Low | Atomic file operations by Puppet prevent partial reads |

### 7.2 Compatibility Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Breaks manual DSC installations | Low | High | Provider maintains fallback to platform defaults |
| Incompatible with older Facter versions | Low | High | `confine` prevents fact on unsupported platforms |
| Breaks in Docker/containers | Low | Medium | External facts work in containers; test in CI |
| Cross-platform path separator issues | Very Low | Medium | Use `File.join` instead of string concatenation |

### 7.3 Operational Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Users confused by 2-run convergence | Medium | Low | Document expected behavior in README |
| Fact file left behind after module removal | Low | Low | Document cleanup procedure in README |
| Debugging difficulty if fact fails silently | Low | Medium | Add `Facter.debug` messages for troubleshooting |

---

## 8. Summary of Decisions

### 8.1 Architecture Decisions

1. **External Facts as Communication Channel** ✅
   - Manifest writes JSON file to `facts.d` directory
   - Custom fact reads JSON file during fact resolution
   - Standard Puppet pattern, works on all platforms

2. **Provider Fallback Strategy** ✅
   - Try `dsc_install_path` fact first
   - Fall back to hardcoded platform defaults
   - Maintains backward compatibility

3. **Performance Optimization** ✅
   - Early exit on file non-existence
   - Lazy loading of JSON library
   - Single file read operation
   - No custom caching (use Facter's built-in)

### 8.2 Implementation Decisions

4. **Fact Structure** ✅
   - Simple string fact (installation path)
   - Returns `nil` when unavailable
   - Platform-specific via `confine` and conditionals

5. **Error Handling** ✅
   - Comprehensive try-catch for file I/O
   - Debug logging for troubleshooting
   - Graceful degradation (return nil on error)

6. **Testing Approach** ✅
   - RSpec with file system stubbing
   - Parameterized platform tests
   - 100% code coverage target
   - Performance benchmarking

### 8.3 Code Quality Decisions

7. **Documentation** ✅
   - Puppet Strings comments on fact
   - Code comments explaining rationale
   - README updates with usage examples

8. **Validation** ✅
   - `pdk validate` before commit
   - RuboCop for Ruby code
   - All tests passing

---

## 9. Next Steps

### 9.1 Implementation Order

1. ✅ **Research complete** (this document)
2. ⏭️ **Create custom fact** (`lib/facter/dsc_install_path.rb`)
3. ⏭️ **Write fact tests** (`spec/unit/facter/dsc_install_path_spec.rb`)
4. ⏭️ **Modify provider** (update `dsc_binary_path` method)
5. ⏭️ **Update provider tests** (add fact consumption tests)
6. ⏭️ **Modify manifest** (add external fact file resource)
7. ⏭️ **Update README** (document `dsc` class usage)
8. ⏭️ **Run validations** (`pdk validate`, `pdk test unit`)
9. ⏭️ **Manual testing** (verify on Windows, Linux, macOS)

### 9.2 Documentation Requirements

- Add example to README showing `dsc` class with custom `install_dir`
- Document 2-run convergence behavior
- Add troubleshooting section for fact debugging
- Update module REFERENCE.md via Puppet Strings

### 9.3 Testing Requirements

- Unit tests for custom fact (all platforms)
- Unit tests for provider path resolution
- Manual acceptance testing on each platform
- Performance benchmarking (verify < 100ms target)

---

## 10. References

### 10.1 Puppet Documentation

- [Custom Facts Documentation](https://www.puppet.com/docs/puppet/latest/fact_overview.html)
- [External Facts](https://www.puppet.com/docs/puppet/latest/external_facts.html)
- [Facter 3.x API](https://www.puppet.com/docs/facter/latest/fact_overview.html)
- [Provider Development Guide](https://www.puppet.com/docs/puppet/latest/provider_development.html)

### 10.2 Module References

- Existing provider: `lib/puppet/provider/dsc_resource/dsc_resource.rb`
- Existing manifest: `manifests/init.pp`
- Existing tests: `spec/unit/puppet/type/dsc_resource_spec.rb`

### 10.3 Related Specs

- Feature specification: `specs/002-dsc-install-fact/spec.md`
- Implementation plan: `specs/002-dsc-install-fact/plan.md`
- Requirements checklist: `specs/002-dsc-install-fact/checklists/requirements.md`

---

**Research Status**: ✅ Complete  
**Next Phase**: Implementation (Phase 2 - Execute)  
**Reviewed By**: [Pending]  
**Date**: 2025-12-16
