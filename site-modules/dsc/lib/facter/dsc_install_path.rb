# frozen_string_literal: true

# Custom structured fact to expose DSC v3 installation information.
#
# This fact discovers DSC installations by checking common installation paths
# and querying the binary for version information. It provides a structured
# fact with install_path and version keys.
#
# @return [Hash, nil] A hash containing DSC installation details, or nil if not found
#   - install_path: The absolute path to the DSC installation directory
#   - version: The DSC version string (e.g., "3.0.1")
#
# @example Reading the fact
#   Facter.value(:dscv3_info)
#   # => { 'install_path' => '/opt/dsc', 'version' => '3.0.1' }
#   # => nil (if DSC not installed)
#
# @api public
Facter.add(:dscv3_info) do
  confine kernel: ['windows', 'Linux', 'Darwin']

  setcode do
    # Define common installation paths to check
    search_paths = case Facter.value(:kernel)
                   when 'windows'
                     [
                       'C:/Program Files/DSC/dsc.exe',
                       'C:/ProgramData/Puppetlabs/DSC/dsc.exe',
                     ]
                   when 'Darwin'
                     ['/usr/local/dsc/dsc']
                   else
                     ['/opt/dsc/dsc']
                   end

    # Find first existing DSC binary
    dsc_binary = search_paths.find { |path| File.exist?(path) }
    next nil unless dsc_binary

    # Get installation directory
    install_path = File.dirname(dsc_binary)

    # Query DSC version
    version = begin
                # Execute dsc --version and capture output
                output = Facter::Core::Execution.execute("#{dsc_binary} --version 2>&1", on_fail: nil)
                if output.nil? || output.empty?
                  nil
                else
                  # Parse version from output (format: "dsc 3.0.1" or just "3.0.1")
                  # Extract semantic version pattern
                  match = output.match(/(\d+\.\d+\.\d+)/)
                  match ? match[1] : nil
                end
              rescue StandardError => e
                Puppet.debug("DSC version query failed: #{e.message}") if defined?(Puppet)
                nil
              end

    # Return structured fact only if we have both path and version
    if version
      {
        'install_path' => install_path,
        'version' => version,
      }
    else
      # Binary exists but version query failed - return basic info
      {
        'install_path' => install_path,
        'version' => 'unknown',
      }
    end
  end
end
