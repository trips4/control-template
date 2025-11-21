# @summary Profile to manage apt configurations for my organization
#
#@param update_frequency Frequency of apt updates (e.g., 'daily', 'weekly')
class profile::apt_myorg (
  String $update_frequency = 'daily',
) {
  class { 'apt':
    update => {
      frequency => $update_frequency,
    },
  }
  notify { "Apt update frequency set to ${update_frequency}":
  }
}
