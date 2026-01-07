class profile::hiera_example (
  String $welcome_message = 'This is the dfault welcome message from the profile class.',
) {
  notify { $welcome_message: }
}
