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
  $message1 = @("END_M1":pp/L)
    This password ${encrypted_password} was encrypted via 'eyaml encrypt' cmd and copied into hiera. \
    At catalog compilation the Puppet server decrypted it so it may be used to define resources in the agent's catalog. \
    Its unencrypted value could be exposed in logs or reports if not handled carefully.  We should avoid this way of handling secrets. \
    | END_M1

  $message2 = @("END_M2":pp/L)
    This password ${encrypted_pw} was encrypted via 'eyaml encrypt' cmd and copied into hiera. \
    We typed this parameter as Sensitive in the class definition. \
    At catalog compilation the Puppet server will decrypt and wrap in a 'sensitive' object. \
    As a 'sensitive' object the Puppet Server will take care to ensure it does not end up in logs or reports. \
    To use the sensitive value, you must explicitly unwrap it in your code. \
    Its unencrypted value could be exposed in logs or reports if not handled carefully.  We should avoid this way of handling secrets. \
    | END_M2

  $message3 = @("END_M3":pp/L)
    This password ${encrypted_pw} followed the same pattern as the example above. \
    Encrypted, put in hiera, decrypted and wrapped by Puppet server. \
    As a 'sensitive' object the Puppet Server will take care to ensure it does not end up in logs or reports. \
    This time we used the deferred function along with unwrap to delay the unwrapping until the value is actually needed. \
    This value should never end up in any logs or reports other than on the agent itself.
    | END_M3

  file { '/tmp/encrypted':
    ensure  => file,
    content => $message1,
  }

  file { '/tmp/encrypted_sensitive':
    ensure  => file,
    content => $message2,
  }

  file { '/tmp/encrypted_sensitive_unwrapped':
    ensure  => file,
    content => $message3,
  }

  # file { '/tmp/hiera_encrypted_sensitive':
  #   ensure  => file,
  #   content => "This password ${encrypted_pw} was encrypted and added to hiera.\n
  #   Our class parameter was typed to sensitive, requiring us to assign it as such in hiera\n
  #   Its unencrypted value is protected and can be accessed securely using the 'unwrap' method.",
  # }

  # file { '/tmp/hiera_encrypted_sensitive_unwrapped':
  #   ensure  => file,
  #   content => "This password Deferred(${encrypted_pw.unwrap}) was encrypted and added to hiera.\n
  #   Our class parameter was typed to sensitive, requiring us to assign it as such in hiera.\n
  #   We used the 'unwrap' method to access its unencrypted value at the time we created the file",
  # }
}
