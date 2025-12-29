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
  if $facts['os.family'] == 'RedHat' {
    $groups = ['wheel']
  }
  else {
    $groups = ['sudo']
  }
  notify { "The group is ${groups}":
  }
  case $facts['kernel'] {
    'Linux': {
      user { $username:
        ensure     => present,
        password   => $password,
        shell      => '/bin/bash',
        managehome => true,
        groups     => $groups,
      }
    }
    'windows': {
      # Additional Windows-specific configurations can be added here
    }
    default: {
      fail("Unsupported kernel ${facts['kernel']}")
    }
  }
}
