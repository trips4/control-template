# Quickstart Guide: Puppet-DSC V3 Integration

**Feature**: 001-dsc-v3-integration  
**Audience**: Puppet developers, DevOps engineers  
**Time to Complete**: 15 minutes  
**Date**: 2025-11-10

---

## Prerequisites

Before using the puppetlabs-dsc module, ensure the following are installed on your managed nodes:

1. **PowerShell 7.2 or newer**
   ```bash
   # Check PowerShell version
   pwsh --version
   ```

2. **DSC V3**
   
   DSC must be installed at the standard location for your platform:
   - **Windows**: `C:\Windows\DSC\dsc.exe`
   - **Linux/macOS/Other**: `/opt/DSC/dsc`
   
   ```powershell
   # Verify DSC is available at the correct location
   # Windows:
   Test-Path C:\Windows\DSC\dsc.exe
   
   # Linux/macOS:
   test -f /opt/DSC/dsc && echo "DSC found" || echo "DSC not found"
   ```
   
   **Note**: Custom installation paths will be configurable in a future release.

3. **DSC Resource Modules** (install modules for resources you'll use)
   ```powershell
   # Example: Install Microsoft.Windows DSC module
   pwsh -Command "Install-PSResource -Name Microsoft.Windows"
   ```

4. **Puppet Agent 8.0 or newer**
   ```bash
   puppet --version
   ```

---

## Installation

### Step 1: Install the Module

**From Puppet Forge** (recommended):
```bash
puppet module install puppetlabs-dsc
```

**From Puppetfile** (for r10k/Code Manager):
```ruby
mod 'puppetlabs-dsc', '1.0.0'
```

**Verify Installation**:
```bash
puppet module list | grep dsc
```

---

## Basic Usage

### Example 1: Configure Windows Registry

**Manifest** (`examples/registry.pp`):
```puppet
# Ensure a registry key value is set
dsc_resource { 'app_config_path':
  type  => 'Microsoft.Windows/Registry',
  input => {
    keyPath   => 'HKLM:\Software\MyApp',
    valueName => 'ConfigPath',
    valueData => 'C:\ProgramData\MyApp\config.json',
  },
  ensure => present,
}
```

**Apply**:
```bash
puppet apply examples/registry.pp
```

**Expected Output**:
```
Notice: Compiled catalog for mynode.example.com in environment production in 0.15 seconds
Notice: /Stage[main]/Main/Dsc_resource[app_config_path]/ensure: created
Notice: Applied catalog in 2.34 seconds
```

---

### Example 2: Cross-Platform Package Management

**Manifest** (`examples/package.pp`):
```puppet
# Install nginx using DSC (works on Windows, Linux, macOS)
dsc_resource { 'install_nginx':
  type  => 'DSC/Package',
  input => {
    name   => 'nginx',
    ensure => 'present',
  },
}
```

**Apply on Linux**:
```bash
puppet apply examples/package.pp
```

**Expected Output**:
```
Notice: /Stage[main]/Main/Dsc_resource[install_nginx]/ensure: created
Info: DSC resource 'install_nginx' installed package nginx
```

---

### Example 3: Using an Adapter

**Manifest** (`examples/adapter.pp`):
```puppet
# Configure a resource via a DSC adapter
dsc_resource { 'custom_config':
  type    => 'Custom/AppConfig',
  adapter => 'MyAdapter',
  input   => {
    setting1 => 'value1',
    setting2 => 'value2',
  },
}
```

**Apply**:
```bash
puppet apply examples/adapter.pp
```

---

## Advanced Usage

### Example 4: Dependency Ordering

Combine DSC resources with native Puppet resources:

**Manifest** (`examples/composite.pp`):
```puppet
# Ensure PowerShell is installed first
package { 'powershell':
  ensure => '7.4.0',
}

# Then configure registry (requires PowerShell)
dsc_resource { 'ps_config':
  type    => 'Microsoft.Windows/Registry',
  input   => {
    keyPath   => 'HKLM:\Software\PowerShell',
    valueName => 'Version',
    valueData => '7.4.0',
  },
  require => Package['powershell'],
}

# Finally, restart service if registry changed
service { 'myapp':
  ensure    => running,
  subscribe => Dsc_resource['ps_config'],
}
```

**What Happens**:
1. Puppet installs PowerShell package
2. DSC configures registry key
3. If registry changed, Puppet restarts service

---

### Example 5: Noop Mode (Dry Run)

Preview changes without applying:

```bash
puppet apply --noop examples/registry.pp
```

**Output**:
```
Notice: Compiled catalog for mynode.example.com in environment production in 0.15 seconds
Notice: /Stage[main]/Main/Dsc_resource[app_config_path]/ensure: current_value absent, should be present (noop)
Notice: Would have triggered 'refresh' from 1 event
Notice: Applied catalog in 1.87 seconds
```

DSC's `--what-if` flag is automatically used in noop mode.

---

## Common Patterns

### Pattern: Idempotent Configuration

DSC resources are idempotent by design. Running the same manifest multiple times only applies changes when needed:

```bash
# First run: Creates registry key
puppet apply examples/registry.pp
# Notice: /Stage[main]/Main/Dsc_resource[app_config_path]/ensure: created

# Second run: No changes (already in desired state)
puppet apply examples/registry.pp
# Notice: Applied catalog in 1.23 seconds (no changes)
```

---

### Pattern: Complex Nested Properties

DSC resources with complex structures:

```puppet
dsc_resource { 'firewall_rule':
  type  => 'Microsoft.Windows/Firewall',
  input => {
    ruleName    => 'Allow HTTP',
    direction   => 'Inbound',
    action      => 'Allow',
    protocol    => 'TCP',
    localPort   => ['80', '443'],
    remoteAddress => {
      subnet => '10.0.0.0/8',
      range  => ['192.168.1.1', '192.168.1.254'],
    },
  },
}
```

Puppet hashes and arrays translate directly to DSC YAML structures.

---

## Troubleshooting

### Issue: "DSC resource type not found"

**Error Message**:
```
Error: DSC resource 'myresource' failed: Resource type 'Foo/Bar' could not be found.
```

**Solution**: Install the DSC module containing the resource:
```powershell
pwsh -Command "Install-PSResource -Name Foo"
```

---

### Issue: "PowerShell not found"

**Error Message**:
```
Error: Could not find PowerShell 7.2+ on this system
```

**Solution**: Install PowerShell 7.2 or newer:
- **Windows**: Download from [PowerShell GitHub releases](https://github.com/PowerShell/PowerShell/releases)
- **Linux**: `sudo apt-get install powershell` (Ubuntu/Debian)
- **macOS**: `brew install powershell`

---

### Issue: "DSC command not available"

**Error Message**:
```
Error: DSC binary not found at expected location
```

**Solution**: Ensure DSC is installed at the correct location for your platform:

**Windows**:
```powershell
# DSC must be at: C:\Windows\DSC\dsc.exe
# If installed elsewhere, create a symbolic link or move the binary
```

**Linux/macOS**:
```bash
# DSC must be at: /opt/DSC/dsc
# If installed elsewhere, create a symbolic link:
sudo ln -s /path/to/your/dsc /opt/DSC/dsc
```

**Note**: Configurable installation paths will be supported in a future module release.

---

### Issue: "DSC command not available" (Legacy)

**Error Message**:
```
Error: 'dsc' command not found in PowerShell session
```

**Solution**: Install DSC V3:
```powershell
pwsh -Command "Install-PSResource -Name PSDesiredStateConfiguration -Version 3.0.0"
```

---

### Issue: Property validation errors

**Error Message**:
```
Error: DSC resource 'example' failed: Property 'keyPath' must be a valid registry path
```

**Solution**: Check the DSC resource documentation for correct property format:
```powershell
# View DSC resource schema
pwsh -Command "dsc resource get --resource Microsoft.Windows/Registry"
```

---

## Testing Your Configuration

### Test Mode (Check Without Applying)

Use `puppet apply --noop` to see what would change:

```bash
puppet apply --noop mymanifest.pp
```

### Validate Catalog Compilation

Ensure your manifest compiles correctly:

```bash
puppet parser validate mymanifest.pp
```

### Check DSC Resource Availability

Verify a DSC resource is installed:

```powershell
pwsh -Command "dsc resource list | Select-String 'Microsoft.Windows/Registry'"
```

---

## Next Steps

### Learn More

- **Full Documentation**: See `REFERENCE.md` for complete type and parameter reference
- **Examples**: Browse `examples/` directory for more use cases
- **DSC Resources**: Explore [PowerShell Gallery](https://www.powershellgallery.com/) for available DSC modules

### Integration with Puppet Infrastructure

**With Puppet Server**:
```ruby
# site.pp or role/profile
node 'webserver.example.com' {
  dsc_resource { 'iis_feature':
    type  => 'Microsoft.Windows/WindowsFeature',
    input => {
      name   => 'Web-Server',
      ensure => 'present',
    },
  }
}
```

**With Hiera**:
```yaml
# hiera.yaml
dsc_resources:
  app_config:
    type: 'Microsoft.Windows/Registry'
    input:
      keyPath: 'HKLM:\Software\MyApp'
      valueName: 'Setting'
      valueData: '%{lookup("app_setting_value")}'
```

```puppet
# manifest
lookup('dsc_resources').each |$name, $attrs| {
  dsc_resource { $name:
    * => $attrs,
  }
}
```

---

## Tips and Best Practices

### 1. Use Puppet's Dependency Graph

Always declare dependencies between resources:
```puppet
dsc_resource { 'config':
  require => Package['dependency'],
  notify  => Service['myapp'],
}
```

### 2. Test Incrementally

Start with simple resources, then add complexity:
1. Get a single DSC resource working
2. Add dependencies
3. Integrate with existing Puppet manifests

### 3. Version-Pin DSC Modules

Document which DSC module versions you've tested:
```puppet
# Requires Microsoft.Windows DSC module >= 0.5.0
dsc_resource { 'registry_key':
  type => 'Microsoft.Windows/Registry',
  # ...
}
```

### 4. Use Noop Mode Liberally

Always test changes in noop mode first:
```bash
puppet apply --noop manifest.pp  # Preview changes
puppet apply manifest.pp         # Apply after review
```

### 5. Monitor Performance

DSC resources add 1-2 seconds per resource. For large catalogs:
- Group related configurations
- Consider splitting into multiple Puppet runs if needed
- Profile catalog application times: `puppet apply --profile`

---

## Support and Feedback

- **Issues**: [GitHub Issues](https://github.com/puppetlabs/puppetlabs-dsc/issues)
- **Documentation**: [Puppet Forge](https://forge.puppet.com/modules/puppetlabs/dsc)
- **Community**: [Puppet Community Slack](https://slack.puppet.com/)

---

**Version**: 1.0.0  
**Last Updated**: 2025-11-10
