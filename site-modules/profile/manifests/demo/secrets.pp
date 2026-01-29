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
class profile::demo::secrets (
  # BAD: plain String password (decrypted at compile time, stored in catalog)
  String $insecure_password,

  # BETTER/BEST: password typed as Sensitive
  Sensitive[String] $sensitive_password,
) {
  # ──────────────────────────────────────────────
  # 1. BAD EXAMPLE – plain String in logs & catalog
  # ──────────────────────────────────────────────

  $message1 = @("END_M1")
    This password (${insecure_password}) was encrypted with 'eyaml encrypt' and stored in Hiera,
but our class parameter is just a plain String.
At catalog compilation time, the Puppet Server decrypts it and puts the clear-text value
directly into the catalog. That catalog can end up in PuppetDB and may be visible in the
Puppet Enterprise console and logs.
We should avoid handling secrets this way.
END_M1

  file { '/tmp/1_insecure_password.txt':
    ensure  => file,
    mode    => '0600',
    content => $message1,
  }

  # ──────────────────────────────────────────────
  # 2. BETTER EXAMPLE – Sensitive value in logs/catalog
  # ──────────────────────────────────────────────
  # Here we keep the value wrapped in Sensitive. When Puppet tries to show it
  # (e.g. interpolation, logs), it prints: Sensitive [value redacted]
  # so the real value is not exposed in logs or the PE console.
  # BUT: the underlying plain value still exists in the catalog in memory.
  # This is an improvement, but not perfect.

  $message2 = @("END_M2")
    This password (${sensitive_password}) was also encrypted with 'eyaml encrypt' and stored in Hiera,
but this time our class parameter type is Sensitive[String].
At catalog compilation, the Puppet Server decrypts it and wraps it in a Sensitive object.
When we interpolate it, Puppet will not show the real value. Instead, it shows:
  ${sensitive_password}
This keeps the value out of logs and reports, but the decrypted value still exists
inside the compiled catalog on the Server.
END_M2

  file { '/tmp/2_sensitive_redacted_in_logs.txt':
    ensure  => file,
    mode    => '0600',
    content => $message2,
  }

  # ──────────────────────────────────────────────
  # 3. BEST EXAMPLE – Sensitive + Deferred unwrap on the agent
  # ──────────────────────────────────────────────
  # Here we:
  #   - Keep the value as Sensitive on the Puppet Server
  #   - Use Deferred('unwrap', ...) so the unwrapping happens ONLY on the agent
  #   - The catalog contains a Deferred function, not the clear-text password
  #   - The real password only exists on the node at apply time, never in PuppetDB
  #
  # This is the recommended way to handle secrets when writing them to files.

  $message3 = @("END_M3")
    In this example, we still use a Sensitive[String] value from Hiera,
but we combine it with a Deferred function: Deferred('unwrap', [${sensitive_password}]).

The unwrap does NOT happen on the Puppet Server.
Instead, the catalog contains a deferred function call, and the unwrap is executed
by the agent when it applies its catalog. That means:

  * The Puppet Server never stores the plain-text password in the catalog
  * PuppetDB never sees the plain-text password
  * Logs and reports only show that the file was managed, not the secret
  * The real value only exists on the node at apply time

The file below (/tmp/3_sensitive_deferred_secret.txt) contains the real password,
but that value never appears in logs or the PE console.
END_M3

  file { '/tmp/3_sensitive_deferred_explained.txt':
    ensure  => file,
    mode    => '0644',
    content => $message3,
  }

  # This file gets the *actual* secret, unwrapped on the agent only.
  file { '/tmp/3_sensitive_deferred_secret.txt':
    ensure  => file,
    mode    => '0600',
    content => Deferred('unwrap', [$sensitive_password]),
  }
}
