class profile::base::windows {
  include chocolatey
  package { '7zip':
    ensure   => installed,
    provider => 'chocolatey',
  }
  dsc_resource { 'example_file':
    adapter    => 'Microsoft.Windows/WindowsPowerShell',
    type       => 'PSDesiredStateConfiguration/File',
    properties => {
      'DestinationPath' => 'C:/test.txt',
      'Contents'        => 'Hello from Puppet!',
    },
  }
}
