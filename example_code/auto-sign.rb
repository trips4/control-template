#!/opt/puppetlabs/puppet/bin/ruby

require 'puppet'
require 'puppet/util'
require 'puppet/ssl'

DEBUG = ENV['AUTOSIGN_DEBUG']

def debug(msg)
  puts "[DEBUG] #{msg}" if DEBUG
end

csr_path = ARGV[0]
unless csr_path && File.exist?(csr_path)
  debug("CSR file not found: #{csr_path}")
  exit 1
end

debug("Reading CSR from: #{csr_path}")
csr_content = File.read(csr_path)
csr = Puppet::SSL::CertificateRequest.from_s(csr_content)

# Extract custom extension pp_preshared_key and extension pp_project
pp_preshared_key = nil
csr.custom_attributes.each do |attr|
  if attr['name'] == 'pp_preshared_key' || attr['oid'] == '1.3.6.1.4.1.34380.1.1.4'
    pp_preshared_key = attr['value']
    break
  end
end

unless pp_preshared_key
  debug("pp_preshared_key not found in CSR")
  exit 1
end

pp_project = nil
csr.request_extensions.each do |attr|
  if attr['name'] == 'pp_project' || attr['oid'] == '1.3.6.1.4.1.34380.1.1.7'
    pp_project = attr['value']
    break
  end
end

unless pp_project
  debug("pp_project not found in CSR")
  exit 1
end

debug("pp_preshared_key from CSR: #{pp_preshared_key}")
debug("pp_project from CSR: #{pp_project}")


require 'json'
PUPPET_BIN = '/opt/puppetlabs/puppet/bin/puppet'

def hiera_lookup(key)
  cmd = [PUPPET_BIN, 'lookup', key, '--render-as', 'json']
  debug("Running: #{cmd.join(' ')}")
  result = `#{cmd.join(' ')}`
  begin
    value = JSON.parse(result)
  rescue => e
    debug("Error parsing lookup result: #{e}")
    value = nil
  end
  value
end

cust_lookup_key = "#{pp_project}::pp_preshared_key"
#expected_key = hiera_lookup('pp_preshared_key')
expected_key = hiera_lookup(cust_lookup_key)

debug("pp_preshared_key from Hiera: #{expected_key}")

if pp_preshared_key == expected_key
  debug("pp_preshared_key matches. Autosign allowed.")
  exit 0
else
  debug("pp_preshared_key does not match. Autosign denied.")
  exit 1
end