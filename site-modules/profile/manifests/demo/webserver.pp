class profile::demo::webserver {

  class demo::apache {
    package { 'apache2':
      ensure => installed,
    }

    file { '/var/www/html/index.html':
      ensure  => file,
      content => 'Hello from Puppet!',
      require => Package['apache2'],
    }

    service { 'apache2':
      ensure    => running,
      enable    => true,
      subscribe => File['/var/www/html/index.html'],
    }
  }
}
