# @summary Example of DSC class installation
#
# This example demonstrates installing DSC v3 on a system with
# custom configuration options.
#
# @example Basic DSC installation
#   include dsc
#
# @example Custom installation directory and version
#   class { 'dsc':
#     install_dir => 'C:/ProgramData/Puppetlabs/DSC',
#     version     => 'v3.0.1',
#   }
#
# The dsc class will:
# - Download and install DSC v3 binary
# - Configure system PATH for dsc command
# - Create dscv3_info fact for discovery
# - Validate installation before proceeding
class dsc::examples::init {
  # Install DSC with custom options
  class { 'dsc':
    install_dir => 'C:/ProgramData/Puppetlabs/DSC',
    version     => 'v3.0.1',
  }

  # Example DSC resource after installation
  dsc_resource { 'example_registry':
    type       => 'Microsoft.Windows/Registry',
    properties => {
      'keyPath'   => 'HKLM\Software\PuppetDSCExample',
      'valueName' => 'TestValue',
      'valueData' => {
        'String' => 'This value is managed by Puppet using DSC v3!',
      },
    },
    require    => Class['dsc'],
  }
}
