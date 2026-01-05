# Quickstart Guide: DSC Installation Path Detection

**Feature**: 002-dsc-install-fact  
**Audience**: Module developers and users  
**Time to Complete**: 5 minutes

---

## What This Feature Does

This feature enables the `dsc_resource` provider to automatically discover where DSC v3 is installed when managed by the module's `dsc` class. No more hardcoded paths or manual configuration!

**Before this feature**:
```puppet
# User had to manually install DSC at hardcoded paths:
# Windows: C:\Windows\DSC\dsc.exe
# Linux: /opt/DSC/dsc

dsc_resource { 'example':
  type       => 'PSDesiredStateConfiguration/File',
  properties => { 'DestinationPath' => '/tmp/test.txt' },
}
```

**After this feature**:
```puppet
# Module installs and manages DSC automatically
include dsc

dsc_resource { 'example':
  type       => 'PSDesiredStateConfiguration/File',
  properties => { 'DestinationPath' => '/tmp/test.txt' },
}
# Provider automatically finds DSC wherever the module installed it!
```

---

## Quick Start for Users

### Step 1: Include the `dsc` Class

Add to your Puppet manifest:

```puppet
include dsc
```

This installs DSC v3 to platform-specific defaults:
- **Windows**: `C:/Program Files/DSC`
- **Linux**: `/opt/dsc`
- **macOS**: `/usr/local/dsc`

### Step 2: Use DSC Resources

```puppet
dsc_resource { 'manage_file':
  type       => 'PSDesiredStateConfiguration/File',
  properties => {
    'DestinationPath' => '/etc/myapp/config.txt',
    'Contents'        => 'production',
  },
}
```

The provider automatically finds DSC at the path configured in Step 1!

### Step 3: (Optional) Customize Installation Path

```puppet
class { 'dsc':
  install_dir => '/custom/dsc/location',
}

dsc_resource { 'manage_file':
  type       => 'PSDesiredStateConfiguration/File',
  properties => {
    'DestinationPath' => '/etc/myapp/config.txt',
    'Contents'        => 'production',
  },
}
```

Provider automatically uses `/custom/dsc/location/dsc`!

---

## Complete Working Example

### Basic Usage

```puppet
# site.pp or your node manifest
node 'server01.example.com' {
  # Install DSC v3
  include dsc
  
  # Manage files with DSC
  dsc_resource { 'app_config':
    type       => 'PSDesiredStateConfiguration/File',
    properties => {
      'DestinationPath' => '/etc/myapp/app.conf',
      'Contents'        => 'key=value',
      'Ensure'          => 'Present',
    },
  }
  
  # Restart service when config changes
  service { 'myapp':
    ensure    => running,
    enable    => true,
    subscribe => Dsc_resource['app_config'],
  }
}
```

### Custom Installation Directory

```puppet
node 'server02.example.com' {
  # Install DSC to custom location
  class { 'dsc':
    install_dir => '/usr/local/bin/dsc',
    version     => 'v3.1.2',
  }
  
  # Use DSC resource - provider auto-detects custom path
  dsc_resource { 'system_file':
    type       => 'PSDesiredStateConfiguration/File',
    properties => {
      'DestinationPath' => '/tmp/test.txt',
      'Contents'        => 'Hello from custom DSC!',
    },
  }
}
```

### Cross-Platform Example

```puppet
node default {
  # Install DSC (works on Windows, Linux, macOS)
  include dsc
  
  # Platform-specific file path
  $config_path = $facts['os']['family'] ? {
    'windows' => 'C:/myapp/config.txt',
    default   => '/etc/myapp/config.txt',
  }
  
  dsc_resource { 'cross_platform_file':
    type       => 'PSDesiredStateConfiguration/File',
    properties => {
      'DestinationPath' => $config_path,
      'Contents'        => 'works everywhere',
    },
  }
}
```

---

## How It Works (Under the Hood)

### The Two-Run Convergence Pattern

**First Puppet Run**:
1. `dsc` class installs DSC to configured path
2. `dsc` class writes external fact file: `/etc/puppetlabs/facter/facts.d/dsc_install.json`
3. DSC resources may use fallback paths (if not at defaults)

**Second Puppet Run** (and all subsequent runs):
1. Facter reads external fact file → `$facts['dsc_install_path']` = custom path
2. Provider checks fact first, finds custom path
3. DSC resources execute using custom path
4. Everything works automatically!

### Architecture Diagram

```
┌─────────────────────┐
│  dsc class          │
│  (manifests/init.pp)│
└──────────┬──────────┘
           │ writes
           ↓
┌─────────────────────────────────────┐
│ External Fact File (JSON)           │
│ /etc/.../facter/facts.d/dsc_install │
│ { "dsc_install_path": "/opt/dsc" }  │
└──────────┬──────────────────────────┘
           │ reads
           ↓
┌─────────────────────┐
│ Custom Fact         │
│ dsc_install_path    │
│ (lib/facter/)       │
└──────────┬──────────┘
           │ provides
           ↓
┌─────────────────────┐
│ dsc_resource        │
│ Provider            │
│ (lib/puppet/)       │
└─────────────────────┘
```

---

## Backward Compatibility

### Manual DSC Installations Still Work!

If you already have DSC installed manually, nothing changes:

```puppet
# No dsc class - just use dsc_resource
dsc_resource { 'my_resource':
  type       => 'PSDesiredStateConfiguration/File',
  properties => { ... },
}
```

Provider falls back to platform defaults:
- Windows: `C:\Windows\DSC\dsc.exe`
- Linux/macOS: `/opt/DSC/dsc`

### Migration Path

**Current setup** (manual DSC):
```puppet
# DSC manually installed at default path
dsc_resource { 'example':
  type       => 'PSDesiredStateConfiguration/File',
  properties => { ... },
}
```

**Migrate to module-managed**:
```puppet
# Step 1: Add dsc class (installs to same default path)
include dsc

# Step 2: No changes needed to dsc_resource declarations!
dsc_resource { 'example':
  type       => 'PSDesiredStateConfiguration/File',
  properties => { ... },
}
```

---

## Troubleshooting

### Issue: Provider says "DSC binary not found"

**Cause**: First Puppet run hasn't completed, or `dsc` class not included.

**Solution**: 
1. Verify `dsc` class is included: `puppet resource class dsc`
2. Run Puppet again: `puppet agent -t`
3. Check fact value: `facter dsc_install_path`

### Issue: Custom path not being used

**Cause**: External fact file not written yet.

**Solution**:
```bash
# Check if fact file exists
ls -l /etc/puppetlabs/facter/facts.d/dsc_install.json

# Check fact value
facter dsc_install_path

# If nil, run Puppet again
puppet agent -t
```

### Issue: Permission denied reading fact file

**Cause**: Incorrect file permissions.

**Solution**:
```bash
# Fix permissions (run as root)
chmod 644 /etc/puppetlabs/facter/facts.d/dsc_install.json
```

### Debug Mode

Check what path the provider is using:

```bash
# Enable debug logging
puppet agent -t --debug | grep -i "dsc"

# Check fact resolution
facter -p dsc_install_path
```

---

## Testing Your Setup

### Verify DSC Installation

```bash
# Check if dsc class is applied
puppet resource class dsc

# Check DSC binary exists
# Linux/macOS:
facter dsc_install_path | xargs -I {} ls -l {}/dsc

# Windows:
facter dsc_install_path | % { Test-Path "$_\dsc.exe" }
```

### Verify Fact Resolution

```bash
# Get fact value
facter -p dsc_install_path

# Should return path like:
# /opt/dsc (Linux)
# /usr/local/dsc (macOS)  
# C:/Program Files/DSC (Windows)
```

### Test DSC Resource

```puppet
# test.pp
include dsc

dsc_resource { 'test_file':
  type       => 'PSDesiredStateConfiguration/File',
  properties => {
    'DestinationPath' => '/tmp/puppet_dsc_test.txt',
    'Contents'        => 'Success!',
  },
}
```

```bash
# Apply test manifest
puppet apply test.pp

# Verify file created
cat /tmp/puppet_dsc_test.txt
# Should output: Success!
```

---

## Next Steps

1. **Read the README**: Full documentation at [README.md](../../README.md)
2. **Explore Examples**: See [examples/](../../examples/) directory
3. **Customize Installation**: Check `dsc` class parameters in [manifests/init.pp](../../manifests/init.pp)
4. **Report Issues**: Found a bug? [Open an issue](https://github.com/puppetlabs/puppetlabs-dsc/issues)

---

## FAQ

**Q: Do I need to uninstall my manual DSC installation?**  
A: No! The module is backward compatible. Manual installations at default paths continue to work.

**Q: Can I change the installation path after initial setup?**  
A: Yes! Change the `install_dir` parameter in the `dsc` class and run Puppet again.

**Q: Does this work with Puppet Enterprise?**  
A: Yes! Works with both open-source Puppet and Puppet Enterprise.

**Q: What if I want DSC at multiple paths?**  
A: Not supported. The module manages a single DSC installation per node.

**Q: Can I use this with Bolt?**  
A: Yes! Include the `dsc` class in your Bolt manifests.

---

**Feature Version**: 1.0.0  
**Last Updated**: 2025-12-16  
**Tested Platforms**: Windows, Linux (Ubuntu, RHEL), macOS
