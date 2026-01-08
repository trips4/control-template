class profile::pe::eyaml {
  file { '/etc/eyaml':
    ensure => 'directory',
  }
  file { '/etc/eyaml/config.yaml':
    ensure  => 'file',
    content => 'pkcs7_private_key: "/etc/puppetlabs/puppet/eyaml/keys/private_key.pkcs7.pem"\\n
                pkcs7_public_key:  "/etc/puppetlabs/puppet/eyaml/keys/public_key.pkcs7.pem"',
    require => File['/etc/eyaml'],
  }
  file { '/etc/puppetlabs/puppet/eyaml':
    ensure => 'directory',
  }
}
