class profile::stig::ubuntu2204::v_260579 (
  Boolean $control_enable = true,
) {
  if $control_enable {
    file { '/etc/pam_pkcs11/':
      ensure => directory,
      mode   => '0755',
      owner  => 'root',
      group  => 'root',
    }

    file { '/etc/pam_pkcs11/pam_pkcs11.conf':
      ensure  => file,
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      require => File['/etc/pam_pkcs11/'],
      content => @(END)
        # Minimal pam_pkcs11 configuration for STIG V-260579 compliance
        # This file must not be empty.
        use_mappers=pwent;
        | END
    }
  } else {
    notify { 'STIG V-260579 control is disabled, no changes made.': }
  }
}
