# @summary Complete example: Install PowerShell module and use its DSC resources
#
# This example demonstrates the complete workflow:
# 1. Ensure DSC v3 is installed
# 2. Install PowerShell module containing DSC resources
# 3. Use DSC resources from that module
#
# Classic DSC resources (from PowerShell modules) require the adapter parameter.
# Native DSC v3 resources do not need an adapter.
#
# @example Apply this manifest
#   puppet apply examples/psmodule_with_resources.pp

# Step 1: Ensure DSC v3 is installed
class { 'dsc':
  install_dir => 'C:/ProgramData/Puppetlabs/DSC',
  version     => 'v3.0.1',
}

# Step 2: Install PSDesiredStateConfiguration module (contains classic DSC resources)
# Autorequire: This automatically depends on Class['dsc']
dsc::psmodule { 'PSDesiredStateConfiguration':
  ensure  => present,
  version => '2.0.7',
}

# Step 3: Use File resource from PSDesiredStateConfiguration module
# IMPORTANT: Classic DSC resources require the 'adapter' parameter
# Autorequire: This automatically depends on Class['dsc'] and Dsc::Psmodule['PSDesiredStateConfiguration']
dsc_resource { 'app_config':
  adapter    => 'Microsoft.Windows/WindowsPowerShell',
  type       => 'PSDesiredStateConfiguration/File',
  properties => {
    'DestinationPath' => 'C:/Windows/Temp/app_config.txt',
    'Contents'        => 'Hello World',
    'Ensure'          => 'Present',
  },
}

# Step 4: Use native DSC v3 resource (no adapter needed)
# Autorequire: This automatically depends on Class['dsc'] only
dsc_resource { 'example_registry':
  type       => 'Microsoft.Windows/Registry',
  properties => {
    'keyPath'   => 'HKLM\Software\PuppetDSCExample',
    'valueName' => 'TestValue',
    'valueData' => {
      'String' => 'This value is managed by Puppet using DSC v3!',
    },
  },
}

# Additional examples with other classic DSC resources

# Example: WindowsFeature resource (requires adapter)
# Autorequire handles the dependency on Dsc::Psmodule['PSDesiredStateConfiguration']
dsc_resource { 'telnet_client':
  adapter    => 'Microsoft.Windows/WindowsPowerShell',
  type       => 'PSDesiredStateConfiguration/WindowsFeature',
  properties => {
    'Name'   => 'Telnet-Client',
    'Ensure' => 'Present',
  },
}

# Example: Registry resource from PSDesiredStateConfiguration (requires adapter)
# Autorequire handles the dependency on Dsc::Psmodule['PSDesiredStateConfiguration']
dsc_resource { 'registry_setting':
  adapter    => 'Microsoft.Windows/WindowsPowerShell',
  type       => 'PSDesiredStateConfiguration/Registry',
  properties => {
    'Key'       => 'HKLM:\Software\MyApp',
    'ValueName' => 'InstallPath',
    'ValueData' => 'C:\MyApp',
    'Ensure'    => 'Present',
  },
}
