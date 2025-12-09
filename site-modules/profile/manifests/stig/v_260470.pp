# @summary
#  STIG V-260470: Require password for single-user and maintenance modes (Ubuntu 22.04)
#  This class ensures a grub password is set for root in /etc/grub.d/40_custom and grub is updated.
#
# @param grub_pbkdf2_hash
#  The PBKDF2 hash string for the grub root password.
#

class profile::stig::v_260470 (
  String $grub_pbkdf2_hash,
) {
  file_line { 'set_grub_superuser':
    path  => '/etc/grub.d/40_custom',
    line  => 'set superusers="root"',
    match => '^set superusers=',
  }

  file_line { 'set_grub_password_pbkdf2':
    path  => '/etc/grub.d/40_custom',
    line  => "password_pbkdf2 root ${grub_pbkdf2_hash}",
    match => '^password_pbkdf2',
  }

  exec { 'update-grub':
    command     => '/usr/sbin/update-grub',
    refreshonly => true,
    subscribe   => [File_line['set_grub_superuser'], File_line['set_grub_password_pbkdf2']],
    path        => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
  }
}
