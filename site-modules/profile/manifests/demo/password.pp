# @summary
# Demo profile for handling password values and writing them to a file.
#
# This class demonstrates the use of plain, sensitive, and non-sensitive encrypted password parameters.
#
# @param encrypted_pw Encrypted password value, marked as Sensitive.
# @param encrypted_password Encrypted password value, not marked as Sensitive.
#
# @example
#   class { 'profile::demo::password':
#     encrypted_pw          => Sensitive('encryptedValue'),
#     encrypted_password   => 'encryptedValue',
#   }
class profile::demo::password (
  Sensitive[String] $encrypted_pw,
  String $encrypted_password,
) {
  # notify { 'title':
  #   message => "This is the value from encrypted_pw - ${encrypted_pw.unwrap}",
  # }

  # notify { 'title':
  #   message => "This is the value from encrypted_pw - ${encrypted_pw}",
  # }

  # notify { 'title2':
  #   message => "This is the value from encrypted_password - ${encrypted_password}",
  # }

  file { '/tmp/file1':
    ensure  => 'file',
    content => "This is the value from encrypted_pw - ${encrypted_pw}",
  }

  file { '/tmp/file2':
    ensure  => 'file',
    content => "This is the value from encrypted_pw - ${encrypted_password}",
  }

  file { '/tmp/file3':
    ensure  => 'file',
    content => "This is the value from encrypted_password - ${encrypted_password.unwrap}",
  }

  # file { 'Create Password Demo File':
  #   ensure => 'file',
  #   path   => $file,
  # }

  # concat { $file :
  #   ensure => present,
  #   owner  => 'root',
  #   group  => 'root',
  #   mode   => '0644',
  # }

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
}
