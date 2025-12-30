# @summary Demonstration of autorequire functionality
#
# This example shows how dsc_resource automatically creates dependencies
# without requiring explicit 'require' statements.
#
# Autorequire ensures proper ordering:
# 1. Class['dsc'] is applied first (installs DSC v3)
# 2. Dsc::Psmodule resources are applied next (install PowerShell modules)
# 3. Dsc_resource types are applied last (use the installed resources)
#
# @example Apply this manifest to see autorequire in action
#   puppet apply examples/autorequire_demo.pp --debug
#
# In the debug output, you'll see Puppet automatically creates the relationships:
#   Notice: /Stage[main]/Main/Dsc_resource[app_config]/require: autorequires Class[dsc]
#   Notice: /Stage[main]/Main/Dsc_resource[app_config]/require: autorequires Dsc::Psmodule[PSDesiredStateConfiguration]

# Step 1: Install DSC v3
# This will be applied first due to autorequire
class { 'dsc':
  install_dir => 'C:/ProgramData/Puppetlabs/DSC',
  version     => 'v3.0.1',
}

# Step 2: Install PowerShell module
# This will be applied after Class['dsc'] due to autorequire in the defined type
dsc::psmodule { 'PSDesiredStateConfiguration':
  ensure  => present,
  version => '2.0.7',
  # NOTE: No explicit 'require => Class[dsc]' needed - autorequire handles it
}

# Step 3: Use DSC resource
# This will automatically depend on both Class['dsc'] and Dsc::Psmodule['PSDesiredStateConfiguration']
# NO EXPLICIT REQUIRE STATEMENTS NEEDED!
dsc_resource { 'app_config':
  adapter    => 'Microsoft.Windows/WindowsPowerShell',
  type       => 'PSDesiredStateConfiguration/File',
  properties => {
    'DestinationPath' => 'C:/Windows/Temp/app_config.txt',
    'Contents'        => 'Managed by Puppet with autorequire!',
    'Ensure'          => 'Present',
  },
  # NOTE: No 'require' parameters needed!
  # Autorequire automatically creates dependencies on:
  #   - Class['dsc']
  #   - Dsc::Psmodule['PSDesiredStateConfiguration']
}

# Example with multiple modules
dsc::psmodule { 'ComputerManagementDsc':
  ensure  => present,
  version => '9.1.0',
}

# This resource will automatically depend on ComputerManagementDsc module
dsc_resource { 'computer_name':
  adapter    => 'Microsoft.Windows/WindowsPowerShell',
  type       => 'ComputerManagementDsc/Computer',
  properties => {
    'Name' => 'WEBSERVER01',
  },
  # Autorequires:
  #   - Class['dsc']
  #   - Dsc::Psmodule['ComputerManagementDsc']
}

# Native DSC v3 resources only autorequire Class['dsc'], not psmodule
dsc_resource { 'example_registry':
  type       => 'Microsoft.Windows/Registry',
  properties => {
    'keyPath'   => 'HKLM\Software\PuppetDSCExample',
    'valueName' => 'TestValue',
    'valueData' => {
      'String' => 'Native DSC v3 resource',
    },
  },
  # Autorequires only Class['dsc'] (no PowerShell module needed)
}
