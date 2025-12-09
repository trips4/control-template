# STIG V-260470: Require password for single-user and maintenance modes (Ubuntu 22.04)
# This class ensures a grub password is set for root in /etc/grub.d/40_custom and grub is updated.
#
# To use, provide the grub_pbkdf2_hash parameter with the output from grub-mkpasswd-pbkdf2.
# Example usage:
#   class { 'profile::stig::v_260470':
#     grub_pbkdf2_hash => 'grub.pbkdf2.sha512.10000.XXXX...'
#   }

class profile::stig::v_260470 (
  Sensitive[String] $grub_pbkdf2_hash,
) {
  $custom_line = "set superusers=\"root\"\npassword_pbkdf2 root ${grub_pbkdf2_hash}"

  file_line { 'set_grub_superuser_and_password':
    path  => '/etc/grub.d/40_custom',
    line  => $custom_line,
    match => '^set superusers=|^password_pbkdf2',
  }

  exec { 'update-grub':
    command     => '/usr/sbin/update-grub',
    refreshonly => true,
    subscribe   => File_line['set_grub_superuser_and_password'],
    path        => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
  }
}
