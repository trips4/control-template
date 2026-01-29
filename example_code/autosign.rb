#!/opt/puppetlabs/puppet/bin/ruby
#
# A note on logging:
#   This script's stderr and stdout are only shown at the DEBUG level
#   of the master's logs. This means you won't see the error messages
#   in puppetserver.log by default. All you'll see is the exit code.
#
#   https://docs.puppet.com/puppet/latest/ssl_autosign.html#policy-executable-api
#
# Exit Codes:
#   0 - A matching challengePassword and pp_project combination was found.
#   1 - No challengePassword or pp_project was found.
#   2 - The challengePassword and pp_project combination is invalid.
#
require 'puppet/ssl'

# Define valid password and pp_project combinations
VALID_COMBINATIONS = {
  'asdfasdf' => 'acme',
  'secret1' => 'demo',
  'ABCDEFG' => 'klab',
}

csr = Puppet::SSL::CertificateRequest.from_s(STDIN.read)

# Extract challengePassword
password_attr = csr.custom_attributes.find do |attribute|
  ['challengePassword', '1.2.840.113549.1.9.7'].include? attribute['oid']
end

unless password_attr
  puts 'No challengePassword found. Rejecting certificate request.'
  exit 1
end

password = password_attr['value']

# Extract pp_project from extension requests
project_attr = csr.request_extensions.find do |extension|
  extension['oid'] == 'pp_project' || extension['oid'] == '1.3.6.1.4.1.34380.1.1.7'
end

unless project_attr
  puts 'No pp_project found. Rejecting certificate request.'
  exit 1
end

project = project_attr['value']

# Check if the combination is valid
if VALID_COMBINATIONS[password] == project
  puts "Authorized: challengePassword and pp_project matched (project: #{project})"
  exit 0
else
  puts "Invalid combination: password='#{password}', project='#{project}'"
  exit 2
end