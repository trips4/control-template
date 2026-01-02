class profile::base::windows {
  include dsc
  include chocolatey
  package { '7zip':
    ensure   => installed,
    provider => 'chocolatey',
  }

  package { 'powershell-core':
    ensure   => 'latest',
    provider => 'chocolatey',
  }

  # dsc_resource { 'example_file':
  #   adapter    => 'Microsoft.Windows/WindowsPowerShell',
  #   type       => 'PSDesiredStateConfiguration/File',
  #   properties => {
  #     'DestinationPath' => 'C:/test.txt',
  #     'Contents'        => 'Hello from Puppet!',
  #   },
  # }
}
