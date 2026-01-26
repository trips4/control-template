#!/opt/puppetlabs/puppet/bin/ruby
# Autosign script using:
#   - pp_preshared_key (custom attribute)
#   - pp_environment, pp_role, pp_project (extensions/custom attributes)
#
# Debug:
#   AUTOSIGN_DEBUG=1 ./autosign.rb < csr.pem

require 'puppet'
require 'puppet/ssl'
require 'json'
require 'open3'

LOG_FILE       = '/var/log/puppetlabs/puppet/autosign_psk_hiera.log'
PUPPET_BIN     = '/opt/puppetlabs/puppet/bin/puppet'
HIERA_BASE_KEY = 'autosign::psk'

DEBUG_TO_STDOUT = ENV['AUTOSIGN_DEBUG'] == '1'

def log(msg)
  timestamp = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
  line = "[#{timestamp}] #{msg}"

  begin
    File.open(LOG_FILE, 'a') do |f|
      f.puts(line)
    end
  rescue Errno::EACCES, Errno::ENOENT
    puts("LOGGING ERROR: #{line}") if DEBUG_TO_STDOUT
  end

  puts(line) if DEBUG_TO_STDOUT
end

def hiera_lookup(key, certname)
  cmd = [PUPPET_BIN, 'lookup', key, '--render-as', 'json']

  stdout, stderr, status = Open3.capture3(*cmd)

  unless status.success?
    err = stderr.to_s.strip
    log("DEBUG: lookup(#{key}) failed for #{certname}: #{err}") unless err.empty?
    return nil
  end

  return nil if stdout.nil? || stdout.strip.empty?

  JSON.parse(stdout)
rescue => e
  log("ERROR: lookup(#{key}) exception for #{certname}: #{e.class}: #{e.message}")
  nil
end


# Normalize Puppet CSR attributes / extensions into plain Ruby hashes
def normalize_to_hash(obj, label)
  return {} if obj.nil?

  # If it's already a Hash, stringify keys and return
  if obj.is_a?(Hash)
    h = {}
    obj.each do |k, v|
      h[k.to_s] = v
    end
    return h
  end

  hash = {}

  obj.each do |entry|
    if entry.is_a?(Array) && entry.size == 2
      # Looks like [key, value]
      key, value = entry
      hash[key.to_s] = value
    elsif entry.respond_to?(:oid) && entry.respond_to?(:value)
      # Looks like a Puppet attribute object
      hash[entry.oid.to_s] = entry.value
    elsif entry.is_a?(Hash) && entry.key?('oid') && entry.key?('value')
      # Your case: {"oid"=>"1.3.6.1.4.1.34380.1.1.4", "value"=>"prod-web-good_cust-psk"}
      hash[entry['oid'].to_s] = entry['value']
    else
      # Unknown shape – ignore (or log for deeper debugging)
      # log("DEBUG: Unknown #{label} entry format: #{entry.class}: #{entry.inspect}")
    end
  end

  hash
end

begin
  csr_pem = STDIN.read
  if csr_pem.nil? || csr_pem.empty?
    log('ERROR: No CSR data received on STDIN; denying autosign.')
    exit 1
  end

  csr = Puppet::SSL::CertificateRequest.from_s(csr_pem)
  certname = csr.name rescue 'unknown'

  raw_attrs = csr.respond_to?(:custom_attributes) ? csr.custom_attributes : nil
  raw_exts  = csr.respond_to?(:extension_requests) ? csr.extension_requests : nil

  attrs = normalize_to_hash(raw_attrs, "custom_attributes")
  exts  = normalize_to_hash(raw_exts,  "extension_requests")

  psk  = nil
  env  = nil
  role = nil
  proj = nil

  # Correct OIDs from your CSR:
  #   pp_preshared_key -> 1.3.6.1.4.1.34380.1.1.4   (Attribute)
  #   pp_environment   -> 1.3.6.1.4.1.34380.1.1.12  (Requested Extension)
  #   pp_role          -> 1.3.6.1.4.1.34380.1.1.13  (Requested Extension)
  #   pp_project       -> 1.3.6.1.4.1.34380.1.1.7   (Requested Extension)

  psk  = attrs['pp_preshared_key'] ||
         attrs['1.3.6.1.4.1.34380.1.1.4'] ||
         exts['pp_preshared_key']  ||
         exts['1.3.6.1.4.1.34380.1.1.4']

  env  = attrs['pp_environment'] ||
         attrs['1.3.6.1.4.1.34380.1.1.12'] ||
         exts['pp_environment']  ||
         exts['1.3.6.1.4.1.34380.1.1.12']

  role = attrs['pp_role'] ||
         attrs['1.3.6.1.4.1.34380.1.1.13'] ||
         exts['pp_role']  ||
         exts['1.3.6.1.4.1.34380.1.1.13']

  proj = attrs['pp_project'] ||
         attrs['1.3.6.1.4.1.34380.1.1.7'] ||
         exts['pp_project']  ||
         exts['1.3.6.1.4.1.34380.1.1.7']

  log("DEBUG: raw custom_attributes (#{certname}): #{raw_attrs.class} #{raw_attrs.inspect}")
  log("DEBUG: normalized attrs (#{certname}): #{attrs.inspect}")
  log("DEBUG: raw extension_requests (#{certname}): #{raw_exts.class} #{raw_exts.inspect}")
  log("DEBUG: normalized exts (#{certname}): #{exts.inspect}")
  log("INFO: Processing CSR from #{certname} with env=#{env.inspect}, role=#{role.inspect}, project=#{proj.inspect}, psk=#{psk.inspect}")

  if psk.nil? || psk.to_s.empty?
    log("WARN: CSR from #{certname} missing pp_preshared_key; denying autosign.")
    exit 1
  end

  # Build lookup keys from most specific to least specific
  keys = []

  if env && role && proj
    keys << "#{HIERA_BASE_KEY}::env_role_project::#{env}::#{role}::#{proj}"
  end

  if env && role
    keys << "#{HIERA_BASE_KEY}::env_role::#{env}::#{role}"
  end

  if env && proj
    keys << "#{HIERA_BASE_KEY}::env_project::#{env}::#{proj}"
  end

  if env
    keys << "#{HIERA_BASE_KEY}::env::#{env}"
  end

  if role
    keys << "#{HIERA_BASE_KEY}::role::#{role}"
  end

  if proj
    keys << "#{HIERA_BASE_KEY}::project::#{proj}"
  end

  # Global default
  keys << "#{HIERA_BASE_KEY}::default"

  expected_psk = nil

  keys.each do |key|
    log("DEBUG: Trying Hiera key #{key} for #{certname}")
    value = hiera_lookup(key, certname)
    if value && !value.to_s.empty?
      expected_psk = value.to_s
      log("DEBUG: Found PSK for #{certname} via #{key}")
      break
    else
      log("DEBUG: No PSK returned for #{certname} via #{key}")
    end
  end

  if expected_psk.nil?
    log("WARN: No expected PSK found in Hiera for CSR from #{certname} (env=#{env.inspect}, role=#{role.inspect}, project=#{proj.inspect}); denying.")
    exit 1
  end

  if psk == expected_psk
    log("INFO: CSR from #{certname} approved. env=#{env.inspect}, role=#{role.inspect}, project=#{proj.inspect}")
    exit 0
  else
    log("WARN: CSR from #{certname} has INVALID pp_preshared_key for env=#{env.inspect}, role=#{role.inspect}, project=#{proj.inspect}; denying.")
    exit 1
  end

rescue => e
  log("FATAL: Error processing CSR: #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}")
  exit 1
end