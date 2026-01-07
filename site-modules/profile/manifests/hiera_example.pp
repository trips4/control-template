class profile::hiera_example (
  String $welcome_message,
) {
  notify { $welcome_message: }
}
