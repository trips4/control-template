class profile::demo::password (
  String $plain_text_pw,
  Sensitive[String] $encrypted_pw,
String $encrypted_pw_nosens) {
  # file { '/tmp/password.txt':
  #   ensure  => 'file',
  #   content => "This is the plain text password ${plain_text_pw}\n
  #   This is the encrypted password ${encrypted_pw}\n
  #   This is the encrypted password not protected with sensitive ${encrypted_pw_nosens}",
  # }

  file { '/tmp/password.txt':
    ensure  => 'file',
    content => "@(END),
    This is plain text ${plain_text_pw}
    This is encrypted and sensitive ${encrypted_pw}
    This is the encrypted not flagged sensitive ${encrypted_pw_nosens}
    | END",
  }
}
