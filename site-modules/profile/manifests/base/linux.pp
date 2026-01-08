class profile::base::linux {
  package { ['vim', 'curl']:
    ensure => installed,
  }
  #include profile::sudo_users
  include profile::ssh_config
  include profile::motd
}
