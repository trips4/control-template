# STIG V-260469: Disable Ctrl-Alt-Delete reboot sequence on Ubuntu 22.04
class profile::stig::v_260469 (
  Boolean $control_enable = true,
) {
  if $control_enable == true {
    exec { 'disable_ctrl_alt_del':
      command => '/bin/systemctl disable ctrl-alt-del.target',
      unless  => '/bin/systemctl is-enabled ctrl-alt-del.target | grep -q masked',
      path    => ['/bin', '/usr/bin', '/sbin', '/usr/sbin'],
    }

    exec { 'mask_ctrl_alt_del':
      command => '/bin/systemctl mask ctrl-alt-del.target',
      unless  => '/bin/systemctl status ctrl-alt-del.target | grep -q masked',
      path    => ['/bin', '/usr/bin', '/sbin', '/usr/sbin'],
      require => Exec['disable_ctrl_alt_del'],
    }

    exec { 'reload_systemd_daemon':
      command     => '/bin/systemctl daemon-reload',
      refreshonly => true,
      path        => ['/bin', '/usr/bin', '/sbin', '/usr/sbin'],
      subscribe   => Exec['mask_ctrl_alt_del'],
    }
  }
  else {
    notify { 'STIG V-260469 control is disabled, no changes made.': }
  }
}
