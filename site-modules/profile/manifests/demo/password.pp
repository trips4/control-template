# @summary
# Demo profile for handling password values and writing them to a file.
#
# This class demonstrates the use of plain, sensitive, and non-sensitive encrypted password parameters.
#
# @param plain_text_pw Plain text password value.
# @param encrypted_pw Encrypted password value, marked as Sensitive.
# @param encrypted_pw_nosens Encrypted password value, not marked as Sensitive.
#
# @example
#   class { 'profile::demo::password':
#     plain_text_password         => 'myPassword',
#     encrypted_pw          => Sensitive('encryptedValue'),
#     encrypted_password   => 'encryptedValue',
#   }
class profile::demo::password (
  Sensitive[String] $encrypted_pw,
  String $encrypted_password,
) {
  $file = '/tmp/password_demo.txt'

  # file { 'Create Password Demo File':
  #   ensure => 'file',
  #   path   => $file,
  # }

  concat { $file :
    ensure => present,
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
  }

  # file_line { 'Password 1':
  #   ensure => present,
  #   path   => $file,
  #   line   => "This is the value from plain_text_password - ${plain_text_password}",
  # }
  # file_line { 'Password 2':
  #   ensure => present,
  #   path   => $file,
  #   line   => "This is the value from encrypted_pw - ${encrypted_pw.unwrap}",
  # }
  # file_line { 'Password 3':
  #   ensure => present,
  #   path   => $file,
  #   line   => "This is the value from encrypted_password - ${encrypted_password}",
  # }

  concat::fragment { 'password1':
    target  => $file,
    content => "This is the value from encrypted_pw - ${encrypted_pw.unwrap}\n",
    order   => '02',
  }

  concat::fragment { 'password1':
    target  => $file,
    content => "This is the value from encrypted_password - ${encrypted_password}\n",
    order   => '03',
  }
}
