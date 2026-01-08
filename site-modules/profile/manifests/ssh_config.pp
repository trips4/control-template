# @summary
# Manages SSH server configuration using the puppet-augeasproviders_ssh module.
#
# This class ensures specific SSH and SSHD settings are enforced for security and compliance.
#
# @note
#   This class replaces the example settings from the SAZ-ssh module with augeasproviders_ssh resources.
#
# @see https://forge.puppet.com/modules/herculesteam/augeasproviders_ssh
class profile::ssh_config {
  # Disable X11 forwarding for security
  sshd_config { 'X11Forwarding':
    ensure => present,
    value  => 'no',
  }

  # Enable password authentication (set to 'no' to disable password logins)
  sshd_config { 'PasswordAuthentication':
    ensure => present,
    value  => 'yes',
  }

  sshd_config { 'PrintMotd':
    ensure => present,
    value  => 'yes',
  }
}
