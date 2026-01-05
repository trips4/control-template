# puppetlabs-dsc

A Puppet module for managing Microsoft Desired State Configuration (DSC) Version 3 resources.

## Table of Contents

1. [Description](#description)
1. [Setup - The basics of getting started with dsc](#setup)
    * [What dsc affects](#what-dsc-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with dsc](#beginning-with-dsc)
1. [Usage - Configuration options and additional functionality](#usage)
1. [Reference - Type and parameter documentation](#reference)
1. [Limitations - OS compatibility, etc.](#limitations)
1. [Development - Guide for contributing to the module](#development)

## Description

This module provides a wrapper for managing Microsoft DSC V3 resources through Puppet. It translates Puppet resource declarations into DSC V3 CLI commands, enabling cross-platform configuration management with DSC resources.

DSC V3 is a cross-platform configuration tool from Microsoft that works on Windows, Linux, and macOS. This module allows you to use DSC resources within your Puppet manifests while maintaining Puppet's idempotent behavior.

## Setup

### What dsc affects

This module:

* Executes DSC commands using the `dsc.exe` binary
* Manages system configuration through DSC resources
* Requires PowerShell for execution (via the pwshlib module)
* Creates YAML configuration files for DSC input

### Setup Requirements

**Required:**

* Puppet Agent >= 8.0.0
* PowerShell 7.2 or later
* `puppetlabs/powershell` module (>= 6.0.0) - provides the `pwsh` exec provider
* `puppetlabs/pwshlib` module (automatically installed as a dependency)

**Module Dependencies Installation:**

```bash
puppet module install puppetlabs-powershell --version '>= 6.0.0'
puppet module install puppetlabs-dsc
```

Or using a Puppetfile:
```puppet
mod 'puppetlabs/powershell', '>= 6.0.0'
mod 'puppetlabs/dsc'
```

**DSC Installation:**

DSC V3 can be installed either:
* **Automatically** by including the `dsc` class (recommended)
* **Manually** by installing DSC V3 CLI to platform-specific default paths

### Beginning with dsc

1. Install the module:
   ```bash
   puppet module install puppetlabs-dsc
   ```

2. Include the `dsc` class to automatically install DSC:
   ```puppet
   include dsc
   ```

   This installs DSC to platform-specific defaults:
   * **Windows**: `C:/Program Files/DSC`
   * **Linux**: `/opt/dsc`
   * **macOS**: `/usr/local/dsc`

3. Use DSC resources in your manifests:
   ```puppet
   dsc_resource { 'example_file':
     adapter    => 'Microsoft.Windows/WindowsPowerShell',
     type       => 'PSDesiredStateConfiguration/File',
     properties => {
       'DestinationPath' => 'C:/test.txt',
       'Contents'        => 'Hello from Puppet!',
     },
   }
   ```

   The provider automatically finds DSC at the path configured by the `dsc` class.

**Note**: Full convergence requires two Puppet runs when first using the `dsc` class:
* Run 1: Installs DSC and writes installation path
* Run 2: Provider uses the installation path

## Usage

### Module-Managed DSC Installation

Include the `dsc` class to automatically install and manage DSC:

```puppet
include dsc

dsc_resource { 'manage_config_file':
  adapter    => 'Microsoft.Windows/WindowsPowerShell',
  type       => 'PSDesiredStateConfiguration/File',
  properties => {
    'DestinationPath' => '/etc/myapp/config.txt',
    'Contents'        => 'production',
    'Ensure'          => 'Present',
  },
}
```

Customize the installation directory:

```puppet
class { 'dsc':
  install_dir => '/usr/local/dsc',
}

dsc_resource { 'my_resource':
  adapter    => 'Microsoft.Windows/WindowsPowerShell',
  type       => 'PSDesiredStateConfiguration/File',
  properties => {
    'DestinationPath' => '/tmp/test.txt',
    'Contents'        => 'Hello DSC',
  },
}
```

### Manual DSC Installation

If DSC is already installed at default paths (`C:\Windows\DSC\dsc.exe` on Windows, `/opt/DSC/dsc` on Linux/macOS), you can use `dsc_resource` directly:

```puppet
dsc_resource { 'manage_config_file':
  adapter    => 'Microsoft.Windows/WindowsPowerShell',
  type       => 'PSDesiredStateConfiguration/File',
  properties => {
    'DestinationPath' => '/etc/myapp/config.txt',
    'Contents'        => 'production',
    'Ensure'          => 'Present',
  },
}
```

### Cross-Platform Configuration

The same Puppet code works across platforms:

```puppet
dsc_resource { 'cross_platform_file':
  adapter    => 'Microsoft.Windows/WindowsPowerShell',
  type       => 'PSDesiredStateConfiguration/File',
  properties => {
    'DestinationPath' => $facts['os']['family'] ? {
      'windows' => 'C:/config.txt',
      default   => '/etc/config.txt',
    },
    'Contents'        => template('mymodule/config.erb'),
  },
}
```

### Integration with Puppet Features

Use Puppet relationships and notifications:

```puppet
dsc_resource { 'app_config':
  adapter    => 'Microsoft.Windows/WindowsPowerShell',
  type       => 'PSDesiredStateConfiguration/File',
  properties => {
    'DestinationPath' => '/etc/myapp/app.conf',
    'Contents'        => 'key=value',
  },
  notify     => Service['myapp'],
}

service { 'myapp':
  ensure => running,
  enable => true,
}
```

### Additional Examples

See the `examples/` directory for more usage patterns:
* `examples/dsc_with_custom_path.pp` - Module-managed DSC with custom installation paths
* `examples/puppet_integration.pp` - Integration with Puppet features (relationships, notifications)
* `examples/cross_platform.pp` - Cross-platform configuration patterns

## Reference

See [REFERENCE.md](REFERENCE.md) for detailed type and parameter documentation.

### Managing PowerShell Modules with DSC Resources

PowerShell modules that contain classic DSC resources must be installed before they can be used. Use the `dsc::psmodule` defined type to manage these modules.

**Autorequire**: The module automatically creates dependencies, so you don't need explicit `require` statements. `dsc_resource` will automatically depend on:
- The `dsc` class (ensures DSC v3 is installed)
- Any matching `dsc::psmodule` resources (based on the resource type)

```puppet
# Install DSC v3
class { 'dsc':
  install_dir => 'C:/ProgramData/Puppetlabs/DSC',
  version     => 'v3.0.1',
}

# Install PowerShell module containing DSC resources
dsc::psmodule { 'PSDesiredStateConfiguration':
  ensure  => present,
  version => '2.0.7',
}

# Use resources from the installed module
# NO REQUIRE STATEMENTS NEEDED - autorequire handles dependencies!
dsc_resource { 'app_config':
  adapter    => 'Microsoft.Windows/WindowsPowerShell',
  type       => 'PSDesiredStateConfiguration/File',
  properties => {
    'DestinationPath' => 'C:/Windows/Temp/config.txt',
    'Contents'        => 'Hello World',
    'Ensure'          => 'Present',
  },
}
```

**Key Points:**
* **Classic DSC resources** (from PowerShell modules) require `adapter => 'Microsoft.Windows/WindowsPowerShell'`
* **Native DSC v3 resources** (like `Microsoft.Windows/Registry`) do not need an adapter
* **Autorequire** automatically handles dependency ordering - no explicit `require` needed!

See `examples/autorequire_demo.pp` and `examples/psmodule_with_resources.pp` for complete examples.

### Type: `dsc_resource`

Manages a DSC resource through the DSC V3 CLI.

**Parameters:**

* `type` (String, required): The full DSC resource name (e.g., 'Microsoft.Windows/Registry')
* `adapter` (String, optional): Adapter for classic DSC resources. Use `'Microsoft.Windows/WindowsPowerShell'` for PowerShell-based DSC resources
* `properties` (Hash, required): Hash of DSC resource properties
* `ensure` (Enum['present', 'absent'], default: 'present'): Standard Puppet ensure parameter

## Limitations

**Platform Support:**

* Windows Server 2019, 2022
* Windows 10, 11
* Ubuntu 18.04, 20.04, 22.04
* Debian 10, 11, 12
* RHEL/CentOS/Rocky/AlmaLinux 7, 8, 9

**Known Limitations:**

* DSC binary path is currently hardcoded (configurable paths planned for future release)
* DSC must be pre-installed; this module does not install DSC
* Requires PowerShell 7.2+ (not Windows PowerShell 5.1)

## Troubleshooting

### Error: "Invalid exec provider 'pwsh'"

This error means the `puppetlabs/powershell` module is not installed. The `pwsh` provider is provided by that module.

**Solution:**
```bash
puppet module install puppetlabs-powershell
```

Or add to your Puppetfile:
```puppet
mod 'puppetlabs/powershell', '>= 6.0.0'
```

### Error: "Custom resource not supported" or "Resource type not found"

This error occurs when using **classic DSC resources** (from PowerShell modules) without the required `adapter` parameter.

**Cause:** DSC v3 treats PowerShell-based DSC resources differently than native DSC v3 resources.

**Solution:** Add `adapter => 'Microsoft.Windows/WindowsPowerShell'` to your `dsc_resource` declaration:

```puppet
# WRONG - missing adapter for classic DSC resource
dsc_resource { 'my_file':
  type       => 'PSDesiredStateConfiguration/File',
  properties => { ... },
}

# CORRECT - includes required adapter
dsc_resource { 'my_file':
  adapter    => 'Microsoft.Windows/WindowsPowerShell',
  type       => 'PSDesiredStateConfiguration/File',
  properties => { ... },
}
```

**When to use adapter:**
- **Classic DSC resources** (PowerShell modules): `adapter => 'Microsoft.Windows/WindowsPowerShell'`
  - PSDesiredStateConfiguration/* resources
  - ComputerManagementDsc/* resources
  - Any resource from PowerShell Gallery modules
- **Native DSC v3 resources**: No adapter needed
  - Microsoft.Windows/* resources
  - Microsoft.MacOS/* resources
  - Other command-based DSC resources

See `examples/psmodule_with_resources.pp` for complete working examples.

### Error: PowerShell module not installed

If you get errors about specific DSC resources not being found, you need to install the PowerShell module first:

```puppet
# Install the module containing DSC resources
dsc::psmodule { 'PSDesiredStateConfiguration':
  ensure  => present,
  version => '2.0.7',
}

# Then use resources from that module
dsc_resource { 'my_resource':
  adapter    => 'Microsoft.Windows/WindowsPowerShell',
  type       => 'PSDesiredStateConfiguration/File',
  properties => { ... },
  require    => Dsc::Psmodule['PSDesiredStateConfiguration'],
}
```

For a complete list of known issues, see [GitHub Issues](https://github.com/puppetlabs/puppetlabs-dsc/issues).

## Development

This module follows Puppet Development Kit (PDK) standards.

**Contributing:**

1. Fork the repository
2. Create a feature branch
3. Write tests first (TDD)
4. Implement your changes
5. Ensure `pdk validate` and `pdk test unit` pass
6. Submit a pull request

**Running Tests:**

```bash
# Validate code style and syntax
pdk validate

# Run unit tests
pdk test unit
```

**Architecture:**

See the [specification documents](specs/001-dsc-v3-integration/) for detailed technical information:

* [Feature Specification](specs/001-dsc-v3-integration/spec.md)
* [Implementation Plan](specs/001-dsc-v3-integration/plan.md)
* [Technical Research](specs/001-dsc-v3-integration/research.md)
* [Quickstart Guide](specs/001-dsc-v3-integration/quickstart.md)

For questions or support, please [open an issue](https://github.com/puppetlabs/puppetlabs-dsc/issues).
