
class profile::sudo_users (
  Hash $users,
) {
  # Determine the appropriate admin group based on OS family
  $admin_group = $facts['os']['family'] ? {
    'RedHat' => 'wheel',
    default  => 'sudo',
  }

  # Merge the admin group into each user definition
  $users_with_group = $users.transform_values |$attributes| {
    merge($attributes, { 'groups' => [$admin_group] })
  }

  # Create user resources
  create_resources('user', $users_with_group)
}
