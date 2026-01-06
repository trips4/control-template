# Class: profile::pe_backup
#
# This class manages Puppet Enterprise backup automation.
# It performs the following tasks:
#   - Deploys a backup script to a specified location.
#   - Schedules a cron job to run the backup script weekly.
#   - Cleans up old backup files older than one week.
#
# Parameters:
#   None (all values are hardcoded for simplicity, but can be parameterized if needed)
#
# Resources:
#   - file: Ensures the backup script exists and is executable.
#   - cron: Schedules the backup script to run every Friday at 2:00 AM.
#   - tidy: Removes backup files older than one week to save disk space.
#
class profile::pe_backup {
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
    minute  => '15',
    hour    => '*',
    weekday => '*',
  }

  tidy { 'cleanup pe backup':
    path    => $backup_directory,
    age     => '1w',
    recurse => true,
    matches => ['pe-backup-*.tgz', 'orchestration-services-backup-*.tgz', 'console-services-backup-*.tgz'],
  }
}
