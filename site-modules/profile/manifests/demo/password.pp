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
    content => "This password ${encrypted_password} was encrypted and added tov hiera. During compilation it was decrypted and assigned to 'encrypted_password'/n ",
  }

  file { '/tmp/hiera_encrypted_sensitive':
    ensure  => file,
    content => "This password ${encrypted_pw} was encrypted and added to hiera. Our class parameter was typed to sensitive, requiring us to assign it as such in hiera",
  }

  file { '/tmp/hiera_encrypted_sensitive_unwrapped':
    ensure  => file,
    content => "This password ${encrypted_pw.unwrap} was encrypted and added to hiera. Our class parameter was typed to sensitive, requiring us to assign it as such in hiera.  We then unwrapped it to put it in our config file.",
  }
}
