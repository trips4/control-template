# @summary Integration with Puppet features
#
# This example demonstrates using DSC resources with Puppet's
# relationship and notification features.
#
# @example Resource relationships
#   include dsc::examples::puppet_integration
class dsc::examples::puppet_integration {
  # Manage application configuration file
  # NOTE: Classic DSC resources require the adapter parameter
  dsc_resource { 'app_config':
    adapter    => 'Microsoft.Windows/WindowsPowerShell',
    type       => 'PSDesiredStateConfiguration/File',
    properties => {
      'DestinationPath' => '/opt/myapp/config.json',
      'Contents'        => '{"version": "1.0", "enabled": true}',
      'Ensure'          => 'Present',
    },
    notify     => Service['myapp'],
  }

  # Service depends on configuration
  service { 'myapp':
    ensure    => running,
    enable    => true,
    subscribe => Dsc_resource['app_config'],
  }
}
