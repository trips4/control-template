# @summary Examples for dsc::psmodule defined type
#
# This file demonstrates various usage patterns for managing PowerShell modules
# containing DSC resources using the dsc::psmodule defined type.
#
# @example Install DSC modules for resource management
#   include dsc
#   include dsc::examples::psmodule
#
# NOTE: The dsc class must be applied first to install DSC v3.
# PowerShell 7+ is required for module management.
#
# IMPORTANT: When using resources from PowerShell modules, you must include
# the adapter parameter in your dsc_resource declarations:
#   adapter => 'Microsoft.Windows/WindowsPowerShell'

# Example 1: Install PSDesiredStateConfiguration module
# This module contains core DSC resources like File, Registry, Service
dsc::psmodule { 'PSDesiredStateConfiguration':
  ensure  => present,
  version => '2.0.7',
}

# Example 1a: Using a resource from the installed module
# dsc_resource { 'example_file':
#   adapter    => 'Microsoft.Windows/WindowsPowerShell',
#   type       => 'PSDesiredStateConfiguration/File',
#   properties => {
#     'DestinationPath' => 'C:/Windows/Temp/test.txt',
#     'Contents'        => 'Managed by DSC',
#     'Ensure'          => 'Present',
#   },
#   require    => Dsc::Psmodule['PSDesiredStateConfiguration'],
# }

# Example 2: Install ComputerManagementDsc module
# This module provides resources for computer and domain management
dsc::psmodule { 'ComputerManagementDsc':
  ensure  => present,
  version => '9.1.0',
}

# Example 3: Installation with explicit repository
# Install from the default PowerShell Gallery repository
dsc::psmodule { 'PSDscResources':
  ensure     => present,
  version    => '2.12.0',
  repository => 'PSGallery',
}

# Example 3: Custom repository (enterprise scenario)
# Install from a company internal repository
# dsc::psmodule { 'CompanyDSCResources':
#   ensure     => present,
#   version    => '3.1.0',
#   repository => 'CompanyInternal',
# }

# Example 4: Local file installation (offline/air-gapped scenario)
# Install from a local .nupkg file
# dsc::psmodule { 'OfflineModule':
#   ensure  => present,
#   version => '1.0.0',
#   source  => '/mnt/packages/OfflineModule.1.0.0.nupkg',
# }

# Example 5: Module removal
# Remove a previously installed module
# dsc::psmodule { 'UnwantedModule':
#   ensure  => absent,
#   version => '1.5.2',
# }

# Example 6: Module upgrade scenario
# To upgrade: change version number and apply
# Puppet will remove old version and install new one
dsc::psmodule { 'NetworkingDsc':
  ensure  => present,
  version => '9.0.0',  # Change this to upgrade (e.g., to '9.1.0')
}
