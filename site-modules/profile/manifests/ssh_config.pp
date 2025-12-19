class profile::ssh_config {
  server_options => {
    'X11Forwarding'          => 'no',
    'PasswordAuthentication' => 'yes',
  },
}
