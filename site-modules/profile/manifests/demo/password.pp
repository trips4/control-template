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
  file { '/tmp/hiera_encrypted':
    ensure  => file,
    content => "This password ${encrypted_password} was encrypted via 'eyaml encrypt' cmd and added to hiera.\n
    During compilation it was decrypted and assigned to the 'encrypted_password' via auto-param lookup.\n
    Its unencrypted value could be exposed in logs or reports if not handled carefully.",
  }

  file { '/tmp/hiera_encrypted_sensitive':
    ensure  => file,
    content => "This password ${encrypted_pw} was encrypted and added to hiera.\n
    Our class parameter was typed to sensitive, requiring us to assign it as such in hiera\n
    Its unencrypted value is protected and can be accessed securely using the 'unwrap' method.",
  }

  file { '/tmp/hiera_encrypted_sensitive_unwrapped':
    ensure  => file,
    content => "This password Deferred(${encrypted_pw.unwrap}) was encrypted and added to hiera.\n
    Our class parameter was typed to sensitive, requiring us to assign it as such in hiera.\n
    We used the 'unwrap' method to access its unencrypted value at the time we created the file",
  }


}
