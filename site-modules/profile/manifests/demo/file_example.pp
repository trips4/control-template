class profile::demo {
  file {
    '/tmp/demo_file.txt':
      ensure => 'file',
      source => 'puppet:///modules/profile/demo_file.txt',
  }
}
