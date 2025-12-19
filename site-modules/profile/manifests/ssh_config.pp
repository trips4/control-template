class profile::ssh_config {
  class { 'ssh':
    server_options => {
      'X11Forwarding'          => 'no',
      'PasswordAuthentication' => 'yes',
    },
  }
}
