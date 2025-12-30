# @summary Cross-platform configuration example
#
# This example shows how to manage configuration files across
# different operating systems using DSC.
#
# @example Cross-platform file management
#   include dsc::examples::cross_platform
class dsc::examples::cross_platform {
  # Determine the correct path based on OS
  $config_path = $facts['os']['family'] ? {
    'windows' => 'C:/ProgramData/myapp/config.ini',
    default   => '/etc/myapp/config.ini',
  }

  # Manage configuration file using DSC
  # NOTE: Classic DSC resources require the adapter parameter
  dsc_resource { 'app_config':
    adapter    => 'Microsoft.Windows/WindowsPowerShell',
    type       => 'PSDesiredStateConfiguration/File',
    properties => {
      'DestinationPath' => $config_path,
      'Contents'        => "[database]\nhost=localhost\nport=5432\n\n[application]\ndebug=false\n",
      'Ensure'          => 'Present',
    },
  }
}
