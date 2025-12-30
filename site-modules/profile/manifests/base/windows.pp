class profile::base::windows {
  include chocolatey
  package { '7zip':
    ensure   => installed,
    provider => 'chocolatey',
  }
}
