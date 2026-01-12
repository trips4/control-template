class profile::demo::password (
  String $plain_text_pw,
String $encrypted_pw) {
  file { '/tmp/password.txt':
    ensure  => 'file',
    content => "This is the plain text password ${plain_text_pw}\nThis is the encrypted password ${encrypted_pw}",
  }
}
