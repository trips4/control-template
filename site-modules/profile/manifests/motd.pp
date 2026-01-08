class profile::motd {
  class { 'motd':
    template          => 'profile/motd.epp',
    issue_content     => 'You are logging into my lab.  This is issue.content.',
    issue_net_content => 'This is issue.net.content.',
  }
}
