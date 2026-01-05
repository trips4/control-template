# Quickstart: DSC Resource Type Management

**Feature**: 004-dsc-resource-management  
**Audience**: Puppet administrators implementing this feature  
**Time to Complete**: 10 minutes

## Prerequisites

Before implementing this feature, ensure:

1. ✅ **DSC is installed** - The `dsc` class must be applied first
2. ✅ **PowerShell 7.2+** - Installed as part of DSC installation
3. ✅ **puppetlabs/pwshlib** - Already a dependency of this module
4. ✅ **puppetlabs/stdlib** - Already a dependency of this module
5. ✅ **PDK 3.4.0+** - For development and testing
6. ✅ **Admin/root privileges** - Required for system-wide module installation

## Quick Implementation Path

### Step 1: Define the Type (5 minutes)

Create `manifests/psmodule.pp`:

```puppet
# @summary Manage PowerShell DSC modules
#
# @param ensure
#   Whether the module should be present or absent
#
# @param version
#   Exact semantic version (e.g., '2.0.7'). Required - no 'latest' default.
#
# @param repository
#   PowerShell repository name (default: PSGallery). Mutually exclusive with source.
#
# @param source
#   Local .nupkg file path for offline installation. Mutually exclusive with repository.
#
# @example Install module from PowerShell Gallery
#   dsc::psmodule { 'PSDesiredStateConfiguration':
#     ensure  => present,
#     version => '2.0.7',
#   }
#
# @example Install from custom repository
#   dsc::psmodule { 'CompanyDSCResources':
#     ensure     => present,
#     version    => '3.1.0',
#     repository => 'CompanyInternal',
#   }
#
# @example Remove module
#   dsc::psmodule { 'UnwantedModule':
#     ensure  => absent,
#     version => '1.5.2',
#   }
#
define dsc::psmodule (
  String[1] $version,
  Enum['present', 'absent'] $ensure = 'present',
  Optional[String[1]] $repository = undef,
  Optional[Stdlib::Absolutepath] $source = undef,
) {
  # Validation
  unless $version =~ /^\d+\.\d+\.\d+$/ {
    fail("Version must be in semantic versioning format (X.Y.Z), got: ${version}")
  }

  if $repository and $source {
    fail('Cannot specify both repository and source parameters')
  }

  if $source and !file_exists($source) {
    fail("Source file does not exist: ${source}")
  }

  # Check DSC prerequisite
  unless $facts['dscv3_info'] {
    fail('DSC must be installed before managing PowerShell modules. Apply the dsc class first.')
  }

  # Determine action based on current state
  $module_name = $title
  
  # Execute via PowerShell (implementation in Step 2)
  exec { "psmodule_${module_name}_${ensure}":
    command   => template('dsc/psmodule_manage.ps1.epp'),
    provider  => 'pwsh',
    unless    => template('dsc/psmodule_check.ps1.epp'),
    logoutput => true,
  }
}
```

### Step 2: Create PowerShell Templates (3 minutes)

Create `templates/psmodule_check.ps1.epp`:

```powershell
<%- | String $module_name,
      String $version,
      String $ensure
| -%>
# Check if current state matches desired state
$module = Get-InstalledModule -Name '<%= $module_name %>' -ErrorAction SilentlyContinue

<% if $ensure == 'present' { -%>
# For 'present': check if correct version installed
if ($null -eq $module -or $module.Version -ne '<%= $version %>') {
    exit 1  # Needs action
}
exit 0  # Already correct
<% } else { -%>
# For 'absent': check if module is not installed
if ($null -ne $module) {
    exit 1  # Needs action (still installed)
}
exit 0  # Already absent
<% } -%>
```

Create `templates/psmodule_manage.ps1.epp`:

```powershell
<%- | String $module_name,
      String $version,
      String $ensure,
      Optional[String] $repository,
      Optional[String] $source
| -%>
$ErrorActionPreference = 'Stop'

<% if $ensure == 'present' { -%>
# Install or upgrade module

# Remove old version if exists
$existing = Get-InstalledModule -Name '<%= $module_name %>' -ErrorAction SilentlyContinue
if ($null -ne $existing) {
    Write-Output "Removing existing version $($existing.Version)"
    Uninstall-Module -Name '<%= $module_name %>' -RequiredVersion $existing.Version -Force
}

# Install new version
$installParams = @{
    Name            = '<%= $module_name %>'
    RequiredVersion = '<%= $version %>'
    Scope           = 'AllUsers'
    Force           = $true
}

<% if $repository { -%>
$installParams['Repository'] = '<%= $repository %>'
<% } -%>

Write-Output "Installing <%= $module_name %> version <%= $version %>"
Install-Module @installParams

Write-Output "Successfully installed <%= $module_name %> version <%= $version %>"

<% } else { -%>
# Remove module

$existing = Get-InstalledModule -Name '<%= $module_name %>' -ErrorAction SilentlyContinue
if ($null -ne $existing) {
    Write-Output "Removing <%= $module_name %> version $($existing.Version)"
    Uninstall-Module -Name '<%= $module_name %>' -RequiredVersion $existing.Version -Force
    Write-Output "Successfully removed <%= $module_name %>"
}

<% } -%>

# Invalidate fact cache
$cacheFile = if ($IsWindows) {
    'C:\ProgramData\PuppetLabs\facter\cache\dsc_modules.json'
} else {
    '/var/cache/facter/dsc_modules.json'
}

if (Test-Path $cacheFile) {
    Remove-Item $cacheFile -Force
}
```

### Step 3: Write Tests (2 minutes)

Create `spec/defines/psmodule_spec.rb`:

```ruby
require 'spec_helper'

describe 'dsc::psmodule' do
  let(:title) { 'PSDesiredStateConfiguration' }
  let(:params) do
    {
      ensure: 'present',
      version: '2.0.7',
    }
  end

  let(:facts) do
    {
      dscv3_info: {
        'install_path' => 'C:/Program Files/DSC',
        'version' => '3.0.0',
      },
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts.merge(super()) }

      context 'with ensure => present' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_exec("psmodule_PSDesiredStateConfiguration_present") }
      end

      context 'with ensure => absent' do
        let(:params) { super().merge(ensure: 'absent') }
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_exec("psmodule_PSDesiredStateConfiguration_absent") }
      end

      context 'with invalid version format' do
        let(:params) { super().merge(version: 'latest') }
        it { is_expected.to compile.and_raise_error(/Version must be in semantic versioning format/) }
      end

      context 'with both repository and source' do
        let(:params) { super().merge(repository: 'MyRepo', source: '/path/to/file.nupkg') }
        it { is_expected.to compile.and_raise_error(/Cannot specify both repository and source/) }
      end

      context 'without DSC installed' do
        let(:facts) { os_facts }  # Remove dscv3_info
        it { is_expected.to compile.and_raise_error(/DSC must be installed/) }
      end
    end
  end
end
```

Run tests:
```bash
pdk test unit
```

### Step 4: Add Optional Fact (Optional, 2 minutes)

Create `lib/facter/dsc_modules.rb`:

```ruby
# Fact: dsc_modules
# Purpose: List installed PowerShell modules for DSC

Facter.add(:dsc_modules) do
  confine do
    Facter.value(:dscv3_info) && Facter.value(:dscv3_info)['install_path']
  end

  setcode do
    cache_file = if Facter.value(:os)['family'] == 'windows'
                   'C:/ProgramData/PuppetLabs/facter/cache/dsc_modules.json'
                 else
                   '/var/cache/facter/dsc_modules.json'
                 end

    # Check cache validity
    if File.exist?(cache_file) && (Time.now - File.mtime(cache_file)) < 3600
      begin
        return JSON.parse(File.read(cache_file))
      rescue JSON::ParserError
        # Cache corrupted, regenerate
      end
    end

    # Execute PowerShell to get modules
    require 'puppet/provider/pwsh'
    result = Pwsh::Manager.execute('Get-InstalledModule | Select-Object Name, Version, InstalledLocation, Repository | ConvertTo-Json')

    if result[:exitcode] == 0 && !result[:stdout].empty?
      modules = JSON.parse(result[:stdout])
      
      # Write cache
      FileUtils.mkdir_p(File.dirname(cache_file))
      File.write(cache_file, modules.to_json)
      
      modules
    else
      []
    end
  rescue StandardError => e
    Puppet.debug("Failed to collect dsc_modules fact: #{e.message}")
    []
  end
end
```

## Usage Examples

### Basic Usage

```puppet
# Install PSDesiredStateConfiguration module
dsc::psmodule { 'PSDesiredStateConfiguration':
  ensure  => present,
  version => '2.0.7',
}

# Now use legacy PowerShell DSC resources
dsc_resource { 'WebServerFeature':
  resource_name => 'WindowsFeature',
  module        => 'PSDesiredStateConfiguration',
  properties    => {
    Name   => 'Web-Server',
    Ensure => 'Present',
  },
}
```

### Enterprise Scenario (Custom Repository)

```puppet
# Prerequisite: Register repository (once per system)
# exec { 'register_company_repo':
#   command => @(EOT),
#     Register-PSRepository -Name 'CompanyInternal' `
#       -SourceLocation 'https://packages.company.internal/powershell' `
#       -InstallationPolicy Trusted
#   EOT
#   provider => 'pwsh',
#   unless  => "Get-PSRepository -Name 'CompanyInternal'",
# }

dsc::psmodule { 'CompanyDSCResources':
  ensure     => present,
  version    => '3.1.0',
  repository => 'CompanyInternal',
}
```

### Offline Scenario (Local File)

```puppet
file { '/tmp/OfflineModule.1.0.0.nupkg':
  ensure => file,
  source => 'puppet:///modules/company/OfflineModule.1.0.0.nupkg',
}

dsc::psmodule { 'OfflineModule':
  ensure  => present,
  version => '1.0.0',
  source  => '/tmp/OfflineModule.1.0.0.nupkg',
  require => File['/tmp/OfflineModule.1.0.0.nupkg'],
}
```

### Module Lifecycle

```puppet
# Initially install
dsc::psmodule { 'Pester':
  ensure  => present,
  version => '5.3.0',
}

# Later upgrade (change version in manifest)
dsc::psmodule { 'Pester':
  ensure  => present,
  version => '5.5.0',  # Puppet automatically removes 5.3.0 and installs 5.5.0
}

# Eventually remove
dsc::psmodule { 'Pester':
  ensure  => absent,
  version => '5.5.0',
}
```

## Testing Your Implementation

### Unit Tests
```bash
# Run all unit tests
pdk test unit

# Run just psmodule tests
pdk test unit --tests=spec/defines/psmodule_spec.rb
```

### Integration Tests (Manual)
```bash
# Apply manifest with test module
puppet apply -e "include dsc; dsc::psmodule { 'Pester': ensure => present, version => '5.5.0' }"

# Verify installation
pwsh -Command "Get-InstalledModule -Name Pester"

# Re-apply (should show no changes - idempotency test)
puppet apply -e "include dsc; dsc::psmodule { 'Pester': ensure => present, version => '5.5.0' }"

# Clean up
puppet apply -e "dsc::psmodule { 'Pester': ensure => absent, version => '5.5.0' }"
```

## Validation Checklist

- [ ] PDK validation passes: `pdk validate`
- [ ] All unit tests pass: `pdk test unit`
- [ ] Puppet Strings documentation generated: `puppet strings generate --format markdown`
- [ ] Example file created: `examples/psmodule.pp`
- [ ] REFERENCE.md updated with dsc::psmodule documentation
- [ ] Manual integration test passed on Windows
- [ ] Manual integration test passed on Linux (if PowerShell 7+ available)
- [ ] Idempotency verified (no changes on second run)
- [ ] Upgrade scenario tested (version change)
- [ ] Removal scenario tested (ensure => absent)

## Common Issues and Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| "DSC must be installed" error | `dsc` class not applied | Apply `dsc` class before `dsc::psmodule` resources |
| "Repository not registered" error | Custom repository not configured | Run `Register-PSRepository` before using custom repository |
| "Module not found" error | Wrong module name or version | Verify module exists: `pwsh -Command "Find-Module -Name ModuleName"` |
| "Administrator rights required" | Puppet not running as admin/root | Run Puppet with elevated privileges |
| Changes every run (not idempotent) | `unless` check not working | Review `psmodule_check.ps1.epp` template logic |

## Next Steps

After implementing the basic functionality:

1. **Add fact unit tests**: `spec/unit/facter/dsc_modules_spec.rb`
2. **Add integration tests**: Create acceptance tests using Litmus or Beaker
3. **Update CHANGELOG.md**: Document new feature
4. **Update README.md**: Add usage section for `dsc::psmodule`
5. **Generate REFERENCE.md**: Run `puppet strings generate --format markdown`

## Additional Resources

- [PowerShellGet Documentation](https://docs.microsoft.com/en-us/powershell/module/powershellget/)
- [Puppet Defined Types](https://www.puppet.com/docs/puppet/latest/lang_defined_types.html)
- [puppetlabs/pwshlib Module](https://forge.puppet.com/modules/puppetlabs/pwshlib)
- [Feature Specification](./spec.md)
- [Data Model](./data-model.md)
- [PowerShell Contract](./contracts/powershell-module-management.md)

---

**Total Implementation Time**: ~10 minutes for basic functionality  
**Testing Time**: ~5 minutes for unit tests, ~10 minutes for integration tests  
**Documentation Time**: ~15 minutes for examples and REFERENCE.md

**Ready to implement!** 🚀
