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
  String $plain_text_password,
  Sensitive[String] $encrypted_pw,
  String $encrypted_password,
) {
  $file = '/tmp/password_demo.txt'
  # Write password values to a file for demonstration purposes
  file { 'Write Password 1':
    ensure  => 'file',
    path    => $file,
    content => "This is the value from plain_text_password - ${plain_text_password}",
    append  => true,
  }
  file { 'Write Password 2':
    ensure  => 'file',
    path    => $file,
    content => "This is the value from encrypted_pw - ${encrypted_pw.unwrap}",
    append  => true,
  }
  file { 'Write Password 3':
    ensure  => 'file',
    path    => $file,
    content => "This is the value from encrypted_password - ${encrypted_password}",
    append  => true,
  }
}
