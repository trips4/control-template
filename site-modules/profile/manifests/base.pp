#
# @Summary Base profile class to be included in all roles.
#
# @param username
#  The name of the user to manage.
#
# @param password
#  The password for the user (Sensitive).
#
class profile::base {
  case $facts['kernel'] {
    'Linux': {
      include profile::base::linux
    }
    'windows': {
      include profile::base::windows
    }
    default: {
      fail("Unsupported kernel ${facts['kernel']}")
    }
  }
}
