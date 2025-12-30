# frozen_string_literal: true

# Test helpers for DSC provider testing
module DscTestHelpers
  # Load a JSON fixture file
  #
  # @param filename [String] Name of the fixture file (without path)
  # @return [Hash] Parsed JSON content
  def load_json_fixture(filename)
    fixture_path = File.join(__dir__, '../fixtures/dsc_responses', filename)
    JSON.parse(File.read(fixture_path))
  end

  # Load a YAML fixture file
  #
  # @param filename [String] Name of the fixture file (without path)
  # @return [Hash] Parsed YAML content
  def load_yaml_fixture(filename)
    fixture_path = File.join(__dir__, '../fixtures/dsc_responses', filename)
    YAML.safe_load(File.read(fixture_path))
  end

  # Create a mock Puppet resource for testing
  #
  # @param params [Hash] Resource parameters
  # @return [Puppet::Type::Dsc_resource] Mock resource instance
  def mock_dsc_resource(params = {})
    defaults = {
      name: 'test_resource',
      type: 'PSDesiredStateConfiguration/File',
      properties: {
        'DestinationPath' => '/tmp/test.txt',
        'Contents' => 'test content',
      },
    }
    Puppet::Type.type(:dsc_resource).new(defaults.merge(params))
  end

  # Mock PowerShell execution result
  #
  # @param stdout [String] Standard output
  # @param stderr [String] Standard error
  # @param exitcode [Integer] Exit code
  # @return [Hash] Mock execution result
  def mock_ps_result(stdout: '', stderr: '', exitcode: 0)
    {
      'stdout' => stdout,
      'stderr' => stderr,
      'exitcode' => exitcode,
    }
  end

  # Stub Facter for platform detection
  #
  # @param platform [String] Platform name ('windows', 'linux', etc.)
  def stub_platform(platform)
    allow(Facter).to receive(:value).with(:kernel).and_return(platform)
  end
end

RSpec.configure do |config|
  config.include DscTestHelpers
end
