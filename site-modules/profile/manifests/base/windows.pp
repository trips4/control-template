class profile::base::windows {
  package { '7zip':
    ensure   => installed,
    provider => 'chocolatey',
  }
}
