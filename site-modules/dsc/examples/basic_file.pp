# @summary Example of basic DSC resource management
#
# This example demonstrates managing a simple file using DSC's
# PSDesiredStateConfiguration/File resource.
#
# @example Basic file management
#   include dsc
#   include dsc::examples::basic_file
#
# NOTE: The dsc class must be applied first to install and validate
# the DSC binary. The dsc_resource provider will automatically discover
# the installation path via the dsc_install_path fact.
class dsc::examples::basic_file {
  # Manage a simple text file using DSC
  # NOTE: Classic DSC resources require the adapter parameter
  dsc_resource { 'example_file':
    adapter    => 'Microsoft.Windows/WindowsPowerShell',
    type       => 'PSDesiredStateConfiguration/File',
    properties => {
      'DestinationPath' => 'C:/Windows/Temp/puppet-dsc-example.txt',
      'Contents'        => 'This file is managed by Puppet using DSC!',
      'Ensure'          => 'Present',
    },
  }
}
