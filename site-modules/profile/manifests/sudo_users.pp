##
# @summary
# Manage sudo users with secure password handling and OS-specific admin group assignment.
#
# This class creates user accounts with sudo (or wheel) group membership, securely hashes passwords, and wraps them in Sensitive.
#
# @param users
#   A hash of user definitions. Each key is a username, and each value is a hash of user attributes (including 'password').
#   Passwords are hashed using SHA-512 and wrapped in Sensitive for security.
##

class profile::sudo_users (
  Hash $users,
) {
  # Determine the appropriate admin group based on OS family
  $admin_group = $facts['os']['family'] ? {
    'RedHat' => 'wheel',
    default  => 'sudo',
  }

  # Transform the users hash with proper group and Sensitive password
  $users_with_group = $users.reduce({}) |$memo, $username, $attributes| {
    # Hash the password if provided
    $hashed_password = $attributes['password'] ? {
      undef   => undef,
      default => pw_hash($attributes['password'], 'SHA-512', 'myrandomstring'),
    }

    # Merge original attributes with group and Sensitive password
    $final_attributes = merge($attributes, {
        'groups'   => [$admin_group],
        'password' => $hashed_password ? {
          undef   => undef,
          default => Sensitive($hashed_password),
        }
    })

    # Add this user to the accumulator hash
    merge($memo, { $username => $final_attributes })
  }

  # Create user resources dynamically
  create_resources('user', $users_with_group)
}
