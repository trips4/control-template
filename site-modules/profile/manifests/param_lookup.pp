class profile::param_lookup (
  String $param_lookup_1,
  String $param_lookup_2,
) {
  notify { "Parameter Lookup 1: ${param_lookup_1}": }
  notify { "Parameter Lookup 2: ${param_lookup_2}": }
}
