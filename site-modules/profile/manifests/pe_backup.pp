class profile::pe_backup {
  #
  # This is a placeholder class for PE Backup related configurations.
  # You can add resources and configurations here as needed.
  #
  $backup_script_path = '/usr/local/bin/pe_backup.sh'
  $cron_user          = 'root'
  $backup_directory   = '/var/puppetlabs/backups'

  file { 'puppet backup script':
    ensure  => 'file',
    path    => $backup_script_path,
    content => template('profile/pe_backup.epp'),
    mode    => '0755',
  }

  cron { 'puppet_backup':
    ensure  => present,
    command => $backup_script_path,
    user    => $cron_user,
    minute  => '0',
    hour    => '2',
    weekday => '5',
  }

  tidy { 'cleanup pe backup':
    path    => $backup_directory,
    age     => '1w',
    recurse => true,
    matches => ['pe-backup-*.tgz', 'orchestration-services-backup-*.tgz', 'console-services-backup-*.tgz'],
  }
}
