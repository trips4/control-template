class profile::sudo_users (
  Hash $users
) {
  create_resources('user', $users)
}
