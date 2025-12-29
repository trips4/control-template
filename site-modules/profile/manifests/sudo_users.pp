# class profile::sudo_users (
#   Hash $users,
# ) {
#   # Determine the appropriate admin group based on OS family
#   $admin_group = $facts['os']['family'] ? {
#     'RedHat' => 'wheel',
#     default  => 'sudo',
#   }

#   # Build a new hash with the correct group added
#   $users_with_group = $users.reduce({}) |$memo, $item| {
#     $username   = $item[0]
#     $attributes = $item[1]
#     merge($memo, { $username => merge($attributes, { 'groups' => [$admin_group] }) })
#   }

#   # Create user resources
#   create_resources('user', $users_with_group)
# }

class profile::sudo_users (
  Hash $users,
) {
  # Determine the appropriate admin group based on OS family
  $admin_group = $facts['os']['family'] ? {
    'RedHat' => 'wheel',
    default  => 'sudo',
  }

  # Build a new hash with Sensitive password and correct group
  $users_with_group = $users.reduce({}) |$memo, $item| {
    $username   = $item[0]
    $attributes = $item[1]

    # If password exists, wrap it in Sensitive
    $final_attributes = merge($attributes, {
        'groups'   => [$admin_group],
        'password' => $attributes['password'] ? {
          undef   => undef,
          default => Sensitive($attributes['password']),
        }
    })

    merge($memo, { $username => $final_attributes })
  }

  create_resources('user', $users_with_group)
}
