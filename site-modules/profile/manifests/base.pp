#
# @Summary Base profile class to be included in all roles.
#
# @param username
#  The name of the user to manage.
#
# @param password
#  The password for the user (Sensitive).
#
class profile::base (
  Sensitive[String] $password,
  String $username = 'trips4',
) {
  case $facts['kernel'] {
    'Linux': {
      user { $username:
        ensure     => present,
        password   => $password,
        shell      => '/bin/bash',
        managehome => true,
        groups     => ['sudo'],
      }
      file_line { 'Enable PasswordAuthentication in SSH Dameon config':
        ensure => present,
        #path   => '/etc/ssh/sshd_config',
        path   => '/etc/ssh/sshd_config.d/60-cloudimg-settings.conf',
        line   => 'PasswordAuthentication yes',
        match  => '^PasswordAuthentication',
        notify => Service['sshd'],
      }
      service { 'sshd':
        ensure => running,
        enable => true,
      }
    }
    'windows': {
      # Additional Linux-specific configurations can be added here
    }
    default: {
      fail("Unsupported kernel ${facts['kernel']}")
    }
  }
}
