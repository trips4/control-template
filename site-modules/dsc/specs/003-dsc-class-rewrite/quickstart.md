# Quick Start: DSC Class Usage

**Feature**: 003-dsc-class-rewrite  
**Date**: 2025-12-16  
**Audience**: Puppet module users

## Overview

The `dsc` class automates DSC v3 installation with sensible platform-specific defaults. This guide shows you how to get started in minutes.

## Prerequisites

- Puppet Agent 8.x or newer
- PowerShell 7.2+ installed on target systems
- Network connectivity to GitHub (for DSC download)
- Admin/root privileges for installation

## Basic Usage

### Default Installation

The simplest way to use the module is to include the class with no parameters:

```puppet
include dsc
```

This installs DSC v3 to platform-specific default locations:
- **Windows**: `C:/Program Files/DSC`
- **Linux**: `/opt/dsc`
- **macOS**: `/usr/local/dsc`

DSC is automatically added to the system PATH.

### Using DSC Resources

After including the `dsc` class, you can manage DSC resources:

```puppet
include dsc

dsc_resource { 'example_file':
  type       => 'PSDesiredStateConfiguration/File',
  properties => {
    'DestinationPath' => '/tmp/test.txt',
    'Contents'        => 'Hello from Puppet DSC!',
    'Ensure'          => 'Present',
  },
}
```

**Important**: The first Puppet run installs DSC and writes the fact file. The second run can use DSC resources. This is standard Puppet behavior for external facts.

## Custom Installation Directory

Override the default installation location:

```puppet
class { 'dsc':
  install_dir => '/opt/custom/dsc',
}

dsc_resource { 'my_resource':
  type       => 'PSDesiredStateConfiguration/File',
  properties => {
    'DestinationPath' => '/etc/config.txt',
    'Contents'        => 'Custom path example',
  },
}
```

## Version Pinning

Install a specific DSC version instead of the latest:

```puppet
class { 'dsc':
  version => 'v3.0.0-alpha.5',
}
```

Version must match a GitHub release tag from https://github.com/PowerShell/DSC/releases

## Disable PATH Management

If you don't want DSC added to the system PATH:

```puppet
class { 'dsc':
  manage_path => false,
}
```

The `dsc_resource` provider will still work because it uses the custom fact to locate DSC, not PATH.

## Platform-Specific Examples

### Windows

```puppet
class { 'dsc':
  install_dir => 'D:/Apps/DSC',
}

dsc_resource { 'windows_feature':
  type       => 'PSDesiredStateConfiguration/WindowsFeature',
  adapter    => 'Microsoft.Windows/WindowsPowerShell',
  properties => {
    'Name'   => 'Web-Server',
    'Ensure' => 'Present',
  },
}
```

### Linux (Ubuntu/Debian)

```puppet
include dsc

dsc_resource { 'linux_file':
  type       => 'PSDesiredStateConfiguration/File',
  properties => {
    'DestinationPath' => '/etc/myapp/config.json',
    'Contents'        => '{"setting": "value"}',
    'Ensure'          => 'Present',
  },
}
```

### macOS

```puppet
class { 'dsc':
  install_dir => '/Applications/DSC',
}

dsc_resource { 'macos_file':
  type       => 'PSDesiredStateConfiguration/File',
  properties => {
    'DestinationPath' => '/usr/local/etc/config.ini',
    'Contents'        => 'key=value',
  },
}
```

## Complete Example

A full manifest demonstrating the dsc class with multiple resources:

```puppet
# Install DSC with custom settings
class { 'dsc':
  install_dir => '/opt/dsc',
  version     => 'latest',
  manage_path => true,
}

# Manage application configuration
dsc_resource { 'app_config':
  type       => 'PSDesiredStateConfiguration/File',
  properties => {
    'DestinationPath' => '/etc/myapp/settings.conf',
    'Contents'        => template('mymodule/settings.conf.erb'),
    'Ensure'          => 'Present',
  },
}

# Trigger service restart when config changes
dsc_resource { 'app_data':
  type       => 'PSDesiredStateConfiguration/File',
  properties => {
    'DestinationPath' => '/var/lib/myapp/data.json',
    'Contents'        => '{"initialized": true}',
  },
  notify     => Service['myapp'],
}

service { 'myapp':
  ensure => running,
  enable => true,
}
```

## Troubleshooting

### DSC Not Found

**Problem**: `dsc_resource` fails with "DSC not found" error

**Solution**: 
1. Verify DSC was installed: Check if binary exists at installation path
2. Check fact file: `facter -p dsc_install_path` should return installation directory
3. Run Puppet twice: First run installs DSC, second run uses it

### Permission Denied

**Problem**: Installation fails with permission errors

**Solution**:
- Ensure Puppet runs with admin/root privileges
- Check that installation directory is writable
- On Unix, verify `/opt` or custom parent directory exists with proper permissions

### Download Failures

**Problem**: DSC download fails with network errors

**Solution**:
- Verify network connectivity to github.com
- Check firewall rules allow HTTPS to GitHub
- For air-gapped environments, consider pre-installing DSC manually

### Version Not Found

**Problem**: Specific version fails to download

**Solution**:
- Verify version tag exists at https://github.com/PowerShell/DSC/releases
- Use exact tag format (e.g., `v3.0.0-alpha.5`, not `3.0.0-alpha.5`)
- Use `version => 'latest'` to avoid version issues

## FAQ

### Q: Do I need to include the dsc class for every node?

**A**: Yes, if you want module-managed DSC installation. Alternatively, install DSC manually and it will be detected at default paths.

### Q: Can I change the install_dir after initial installation?

**A**: Yes, but you'll have two DSC installations. Remove the old one manually if needed. The fact file will point to the new location after the next Puppet run.

### Q: Does this work in air-gapped environments?

**A**: Not by default (downloads from GitHub). You would need to pre-install DSC manually or modify the class to use a local mirror.

### Q: How do I upgrade DSC?

**A**: Remove the DSC binary, then run Puppet again. Or set a specific version and remove the existing installation. Automatic upgrades are not currently supported.

### Q: Why does it take two Puppet runs to work?

**A**: The first run installs DSC and writes the external fact file. Facter loads external facts at the start of a Puppet run, so the second run is the first time the fact is available. This is standard Puppet behavior.

### Q: Can I use this with Hiera?

**A**: Yes! Set parameters in Hiera data:

```yaml
---
dsc::install_dir: '/opt/custom/dsc'
dsc::version: 'v3.0.0-alpha.5'
dsc::manage_path: true
```

Then just `include dsc` in your manifests.

## Next Steps

- Read [data-model.md](./data-model.md) for implementation details
- See [contracts/external-fact-schema.md](./contracts/external-fact-schema.md) for fact file format
- Review [examples/](../../examples/) directory for more usage patterns
- Check [spec.md](./spec.md) for complete feature requirements

## Support

For issues or questions:
- Open an issue on GitHub
- Check existing closed issues for similar problems
- Include Puppet version, OS, and DSC version in bug reports
