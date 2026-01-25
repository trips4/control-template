
#!/opt/puppetlabs/puppet/bin/ruby
# Autosign script using:
#   - pp_preshared_key (custom attribute)
#   - pp_environment, pp_role, pp_project (extensions/custom attributes)
#
# It:
#   - Reads CSR from STDIN
#   - Extracts pp_preshared_key, pp_environment, pp_role, pp_project
#   - Queries Hiera via `puppet lookup` to find the expected PSK
#   - Approves (exit 0) if it matches; denies (exit 1) otherwise
#
# Debugging:
#   - Always logs to LOG_FILE
#   - Also prints to STDOUT when AUTOSIGN_DEBUG=1
#   - AUTOSIGN_DEBUG=1 ./autosign.rb < lab1-ubuagt01.triplo.psedemos.com.pem

require 'puppet'
require 'puppet/ssl'
require 'json'
require 'open3'

LOG_FILE       = '/var/log/puppetlabs/puppet/autosign_psk_hiera.log'
PUPPET_BIN     = '/opt/puppetlabs/puppet/bin/puppet'
HIERA_BASE_KEY = 'autosign::psk'

# Enable extra STDOUT debug for manual runs:
#   AUTOSIGN_DEBUG=1 ./autosign_psk_hiera.rb < csr.pem
DEBUG_TO_STDOUT = ENV['AUTOSIGN_DEBUG'] == '1'

def log(msg)
  timestamp = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
  line = "[#{timestamp}] #{msg}"

  # Always write to log file
  begin
    File.open(LOG_FILE, 'a') do |f|
      f.puts(line)
    end
  rescue Errno::EACCES, Errno::ENOENT
    # If logging fails, optionally show on STDOUT during debug
    puts("LOGGING ERROR: #{line}") if DEBUG_TO_STDOUT
  end

  # Optionally also print to STDOUT for interactive debugging
  puts(line) if DEBUG_TO_STDOUT
end

def hiera_lookup(key, certname)
  cmd = [PUPPET_BIN, 'lookup', key, '--render-as', 'json']

  stdout, stderr, status = Open3.capture3(*cmd)

  unless status.success?
    # lookup failure is not fatal; it just means key not found / error
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

begin
  csr_pem = STDIN.read
  if csr_pem.nil? || csr_pem.empty?
    log('ERROR: No CSR data received on STDIN; denying autosign.')
    exit 1
  end

  csr = Puppet::SSL::CertificateRequest.from_s(csr_pem)
  certname = csr.name rescue 'unknown'

  psk  = nil
  env  = nil
  role = nil
  proj = nil

  # Extract from custom_attributes
  if csr.respond_to?(:custom_attributes) && csr.custom_attributes
    csr.custom_attributes.each do |attr|
      case attr['oid']
      when 'pp_preshared_key', '1.3.6.1.4.1.34380.1.1.1'
        psk = attr['value']
      when 'pp_environment', '1.3.6.1.4.1.34380.1.1.2'
        env = attr['value']
      when 'pp_role'
        role = attr['value']
      when 'pp_project'
        proj = attr['value']
      end
    end
  end

  # Some tooling might put these into extension_requests instead
  if csr.respond_to?(:extension_requests) && csr.extension_requests
    env  ||= csr.extension_requests['pp_environment']
    role ||= csr.extension_requests['pp_role']
    proj ||= csr.extension_requests['pp_project']
  end

  log("INFO: Processing CSR from #{certname} with env=#{env.inspect}, role=#{role.inspect}, project=#{proj.inspect}")

  if psk.nil?
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

  # Global default (optional)
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