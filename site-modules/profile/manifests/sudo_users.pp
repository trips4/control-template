
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
  $admin_group = $facts['os']['family'] ? {
    'RedHat' => 'wheel',
    default  => 'sudo',
  }

  $users_with_group = $users.reduce({}) |$memo, $item| {
    $username   = $item[0]
    $attributes = $item[1]

    # Wrap password in Sensitive type if present
    if $attributes['password'] {
      $attributes['password'] = Sensitive($attributes['password'])
    }

    merge($memo, { $username => merge($attributes, { 'groups' => [$admin_group] }) })
  }

  create_resources('user', $users_with_group)
}
