# frozen_string_literal: true

require 'json'

# Traditional Puppet provider for managing DSC resources via DSC V3 CLI
Puppet::Type.type(:dsc_resource).provide(:dsc_resource) do
  desc 'Provider for DSC V3 resources using the dsc command-line tool.'

  # DSC v3 is cross-platform, so no OS confine needed
  # confine operatingsystem: :windows

  # Check if DSC binary exists and is accessible
  # This is a class method called during provider selection
  # Only returns true if dscv3_info fact is present, indicating DSC is installed
  def self.suitable?
    require 'facter'

    # Check for dscv3_info structured fact
    dsc_info = Facter.value(:dscv3_info)

    # Return true only if fact exists and has install_path
    # This prevents provider from being used on first run before DSC is installed
    dsc_info.is_a?(Hash) && dsc_info['install_path'] && !dsc_info['install_path'].empty?
  end

  # Check if the resource exists (is in desired state)
  # This is called by Puppet to determine current state
  # @return [Boolean] true if resource is in desired state, false otherwise
  def exists?
    Puppet.debug("DSC provider: exists? called for resource '#{resource[:name]}' with ensure=#{resource[:ensure]}")

    # Use DSC config test to check if resource is in desired state
    in_desired_state = invoke_dsc_test

    Puppet.debug("DSC resource '#{resource[:name]}' inDesiredState: #{in_desired_state}")

    # For the traditional provider with ensure:
    # - When ensure => present (default): exists? should return true if in desired state
    # - When ensure => absent: exists? should return true if resource exists (opposite of in_desired_state for absent)
    #
    # Since DSC test checks if current state matches desired state:
    # - If we want ensure => present and DSC says inDesiredState=true: resource is good, exists? = true
    # - If we want ensure => present and DSC says inDesiredState=false: need to apply, exists? = false
    # - If we want ensure => absent and DSC says inDesiredState=true: resource doesn't exist, exists? = false
    # - If we want ensure => absent and DSC says inDesiredState=false: resource exists, exists? = true

    result = if resource[:ensure] == :absent
               # For absent, inDesiredState=true means it's already absent, so exists?=false
               # inDesiredState=false means it still exists, so exists?=true (so we can destroy it)
               !in_desired_state
             else
               # For present (default), return the DSC test result directly
               in_desired_state
             end

    Puppet.debug("DSC provider: exists? returning #{result} for resource '#{resource[:name]}'")
    result
  rescue StandardError => e
    Puppet.debug("DSC exists? check failed for '#{resource[:name]}': #{e.message}")
    false
  end

  # Create or update the resource to desired state
  def create
    Puppet.notice("Applying DSC configuration for resource '#{resource[:name]}'")
    invoke_dsc_set
  rescue StandardError => e
    raise Puppet::Error, "Failed to create DSC resource '#{resource[:name]}': #{e.message}"
  end

  # Remove the resource (set ensure => absent)
  def destroy
    Puppet.notice("Removing DSC resource '#{resource[:name]}'")

    # Build properties with Ensure=Absent
    properties = resource[:properties].dup
    properties['Ensure'] = 'Absent'

    # Generate config and apply
    json_content = generate_dsc_config(resource[:name], resource[:type], resource[:schema], properties, resource[:adapter])
    command = "#{dsc_binary_path} config set --output-format json --file -"
    result = execute_powershell(command, json_content)

    if result['exitcode'] != 0
      raise Puppet::Error, "Failed to destroy DSC resource '#{resource[:name]}': #{result['stderr']}"
    end

    Puppet.notice("DSC resource '#{resource[:name]}' removed successfully")
  rescue StandardError => e
    raise Puppet::Error, "Failed to destroy DSC resource '#{resource[:name]}': #{e.message}"
  end

  private

  # Get the platform-specific DSC binary path from dscv3_info fact
  #
  # This method retrieves the installation path from the dscv3_info structured fact
  # and constructs the full path to the DSC binary based on the platform.
  #
  # @return [String] Full path to DSC binary
  # @raise [Puppet::Error] If dscv3_info fact is not available
  def dsc_binary_path
    require 'facter'

    # Get dscv3_info structured fact
    dsc_info = Facter.value(:dscv3_info)

    unless dsc_info.is_a?(Hash) && dsc_info['install_path']
      raise Puppet::Error, 'DSC installation not found. The dscv3_info fact is not available. ' \
                           'Ensure the dsc class has been applied and run Puppet again.'
    end

    install_path = dsc_info['install_path']

    # Construct full binary path
    binary_name = if Facter.value(:kernel) == 'windows'
                    'dsc.exe'
                  else
                    'dsc'
                  end

    File.join(install_path, binary_name)
  end

  # Check if DSC binary exists
  #
  # @return [Boolean] True if DSC binary is found
  def dsc_binary_available?
    File.exist?(dsc_binary_path)
  end

  # Execute DSC config test command
  #
  # @return [Boolean] True if resource is in desired state
  def invoke_dsc_test
    unless dsc_binary_available?
      Puppet.err('DSC binary not found')
      return false
    end

    json_content = generate_dsc_config(resource[:name], resource[:type], resource[:schema], resource[:properties], resource[:adapter])
    Puppet.debug("DSC test JSON config: #{json_content}")

    result = execute_powershell(dsc_binary_path, 'config test --output-format json --file -', json_content)

    Puppet.debug("DSC test exitcode: #{result['exitcode']}")
    Puppet.debug("DSC test stdout length: #{result['stdout'].length}")
    Puppet.debug("DSC test stderr: #{result['stderr']}") unless result['stderr'].empty?

    if result['exitcode'] != 0
      Puppet.err("DSC test failed with exit code #{result['exitcode']}: #{result['stderr']}")
      return false
    end

    if result['stdout'].empty?
      Puppet.err('DSC test returned empty stdout')
      return false
    end

    Puppet.debug("DSC test raw output: #{result['stdout']}")

    output = parse_dsc_output(result['stdout'])
    Puppet.debug("DSC test parsed output: #{output.inspect}")

    unless output['results'] && !output['results'].empty?
      Puppet.err("DSC test output missing results array or empty: #{output.inspect}")
      return false
    end

    result_data = output['results'].first
    Puppet.debug("DSC test result data: #{result_data.inspect}")

    in_desired_state = result_data.dig('result', 'inDesiredState')
    Puppet.debug("DSC test inDesiredState value: #{in_desired_state.inspect}")

    in_desired_state || false
  rescue StandardError => e
    Puppet.err("DSC test error: #{e.message}")
    Puppet.err("Backtrace: #{e.backtrace.join("\n")}")
    false
  end

  # Execute DSC config set command
  #
  # @return [Hash] Result of DSC set operation
  def invoke_dsc_set
    raise Puppet::Error, 'DSC binary not found' unless dsc_binary_available?

    json_content = generate_dsc_config(resource[:name], resource[:type], resource[:schema], resource[:properties], resource[:adapter])
    result = execute_powershell(dsc_binary_path, 'config set --output-format json --file -', json_content)

    if result['exitcode'] != 0
      error_msg = "DSC set failed with exit code #{result['exitcode']}\n"
      error_msg += "STDOUT: #{result['stdout']}\n" unless result['stdout'].empty?
      error_msg += "STDERR: #{result['stderr']}" unless result['stderr'].empty?
      raise Puppet::Error, error_msg
    end

    # If stdout is empty, DSC succeeded but returned no output
    if result['stdout'].empty?
      Puppet.notice("DSC set completed for resource: #{resource[:name]}")
      return { 'hadErrors' => false, 'results' => [] }
    end

    output = parse_dsc_output(result['stdout'])
    Puppet.notice("DSC set completed for resource: #{resource[:name]}")
    output
  rescue StandardError => e
    raise Puppet::Error, "DSC set error: #{e.message}"
  end

  # Generate JSON configuration for DSC
  #
  # @param name [String] Resource instance name
  # @param resource_type [String] DSC resource type
  # @param schema [String] JSON schema URI for the configuration document
  # @param properties [Hash] Resource properties
  # @param adapter [String, nil] Optional adapter type (e.g., Microsoft.Windows/WindowsPowerShell)
  # @return [String] JSON configuration string
  def generate_dsc_config(name, resource_type, schema, properties, adapter = nil)
    config = if adapter
               # When adapter is specified, wrap the resource in adapter structure
               # Following Microsoft's DSC V3 adapter pattern:
               # https://devblogs.microsoft.com/powershell/get-started-with-dsc-v3/#manage-a-basic-configuration
               {
                 '$schema' => schema,
                 'resources' => [
                   {
                     'name' => name,
                     'type' => adapter,
                     'properties' => {
                       'resources' => [
                         {
                           'name' => name,
                           'type' => resource_type,
                           'properties' => properties,
                         },
                       ],
                     },
                   },
                 ],
               }
             else
               # Direct DSC V3 resource (no adapter)
               {
                 '$schema' => schema,
                 'resources' => [
                   {
                     'name' => name,
                     'type' => resource_type,
                     'properties' => properties,
                   },
                 ],
               }
             end
    JSON.generate(config)
  end

  # Parse JSON output from DSC
  #
  # @param json_output [String] JSON string from DSC command
  # @return [Hash] Parsed DSC result
  def parse_dsc_output(json_output)
    result = JSON.parse(json_output)
    raise Puppet::Error, "DSC command failed: #{result['messages']}" if result['hadErrors']

    result
  rescue JSON::ParserError => e
    raise Puppet::Error, "Failed to parse DSC output: #{e.message}"
  end

  # Execute PowerShell command via pwshlib
  #
  # @param command [String] PowerShell command to execute
  # @param stdin_data [String] Optional data to pass via STDIN
  # @return [Hash] Execution result with stdout, stderr, exitcode
  def execute_powershell(dsc_binary, command_args, stdin_data = nil)
    require 'ruby-pwsh'
    require 'base64'

    # Get PowerShell manager instance with pwsh path
    # pwshlib will auto-detect pwsh location
    ps_manager = Pwsh::Manager.instance(Pwsh::Manager.pwsh_path, Pwsh::Manager.pwsh_args)

    # Build PowerShell script to execute DSC command
    ps_script = if stdin_data
                  # Use Base64 encoding to safely pass JSON through PowerShell
                  # This avoids escaping issues and buffer problems
                  encoded_data = Base64.strict_encode64(stdin_data)

                  # Replace --file - with --input $dscConfig in the command args
                  processed_args = command_args.gsub('--file -', '--input $dscConfig')

                  # Store the binary path in a PowerShell variable to avoid quote escaping issues
                  # PowerShell's call operator & can invoke the command from a variable
                  # This avoids parsing problems with paths containing spaces
                  escaped_binary = dsc_binary.gsub("'", "''")

                  # Add error handling to capture exit codes and stderr properly
                  # Exit code -1073741515 (0xC0000135) means DLL not found or missing dependencies
                  "$dscBinary = '#{escaped_binary}'\n" \
                  "$encodedConfig = '#{encoded_data}'\n" \
                  "$dscConfig = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($encodedConfig))\n" \
                  "try {\n" \
                  "  $output = & $dscBinary #{processed_args} 2>&1\n" \
                  "  if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {\n" \
                  "    Write-Error \"DSC command failed with exit code: $LASTEXITCODE\"\n" \
                  "    if ($LASTEXITCODE -eq -1073741515) {\n" \
                  "      Write-Error \"Exit code -1073741515 (0xC0000135) indicates missing DLL dependencies. Ensure DSC binary and all required DLLs are present in: $(Split-Path $dscBinary)\"\n" \
                  "    }\n" \
                  "  }\n" \
                  "  $output\n" \
                  "} catch {\n" \
                  "  Write-Error \"Failed to execute DSC binary: $_\"\n" \
                  "  throw\n" \
                  "}\n"
                else
                  "& '#{dsc_binary.gsub("'", "''")}' #{command_args}"
                end

    # Execute via pwshlib
    result = ps_manager.execute(ps_script)

    # pwshlib may return stderr as an array, convert to string
    stderr_output = result[:stderr]
    stderr_output = stderr_output.join("\n") if stderr_output.is_a?(Array)

    {
      'stdout' => result[:stdout] || '',
      'stderr' => stderr_output || '',
      'exitcode' => result[:exitcode] || 1,
    }
  rescue StandardError => e
    {
      'stdout' => '',
      'stderr' => "PowerShell execution error: #{e.message}",
      'exitcode' => 1,
    }
  end
end
