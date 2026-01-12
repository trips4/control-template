class profile::demo::password (
String $plain_text_pw,
Sensitive[String] $encrypted_pw,
String $encrypted_pw_nosens){
  file { '/tmp/password.txt':
    ensure  => 'file',
    content => "This is the plain text password ${plain_text_pw}\nThis is the encrypted password ${encrypted_pw}\nThis is the encrypted password not protected with sensitive ${encrypted_pw_nosens}",
  }
}
