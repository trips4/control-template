class profile::pe_backup {
  #
  # This is a placeholder class for PE Backup related configurations.
  # You can add resources and configurations here as needed.
  #
  file { 'puppet backup script':
    ensure  => 'file',
    path    => '/usr/local/bin/pe_backup.sh',
    content => template('profile/pe_backup.epp'),
    mode    => '0755',
  }

  schedule { 'daily pe backup':
    range  => '13 - 22',
    period => daily,
    repeat => 1,
  }

  exec { 'run pe backup':
    command  => '/usr/local/bin/pe_backup.sh',
    schedule => 'daily pe backup',
    require  => File['puppet backup script'],
    timeout  => 600,
  }

  tidy { 'cleanup pe backup':
    path    => '/var/puppetlabs/backups',
    age     => '1w',
    recurse => true,
    matches => ['pe-backup-*.tgz', 'orchestration-services-backup-*.tgz', 'console-services-backup-*.tgz'],
  }
}
