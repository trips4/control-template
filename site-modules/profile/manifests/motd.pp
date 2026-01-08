class profile::motd {
  class { 'motd':
    template => 'profile/motd.epp',
  }
}
