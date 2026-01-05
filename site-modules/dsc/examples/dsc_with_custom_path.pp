# Example: Using dsc class with dsc_resource
#
# This example demonstrates how the dsc class automatically manages DSC installation
# and the dsc_resource provider automatically discovers the installation path.
#
# Note: This requires two Puppet runs for full convergence:
# - Run 1: Installs DSC and writes external fact file
# - Run 2: Fact is available, provider uses custom path

# Install DSC v3 to default location
include dsc

# Use DSC resources - provider automatically finds DSC
$destination_path = $facts['os']['family'] ? {
  'windows' => 'C:/temp/test.txt',
  default   => '/tmp/test.txt',
}

dsc_resource { 'example_file':
  type       => 'PSDesiredStateConfiguration/File',
  properties => {
    'DestinationPath' => $destination_path,
    'Contents'        => 'Managed by Puppet with auto-detected DSC!',
    'Ensure'          => 'Present',
  },
}

# Example with custom installation directory
# class { 'dsc':
#   install_dir => '/custom/dsc/path',
# }
#
# dsc_resource { 'custom_file':
#   type       => 'PSDesiredStateConfiguration/File',
#   properties => {
#     'DestinationPath' => '/tmp/custom.txt',
#     'Contents'        => 'Using custom DSC installation!',
#   },
# }
