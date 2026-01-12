class profile::demo::password2 (
String $plain_text_pw, Sensitive[String] $encrypted_pw ) {
  file { '/tmp/password2.txt':
    ensure  => 'file',
    content => Sensitive("This is the encrypted password Sensitive${encrypted_pw}"),
  }
}
