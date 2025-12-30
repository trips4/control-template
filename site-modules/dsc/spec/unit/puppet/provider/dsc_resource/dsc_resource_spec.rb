# frozen_string_literal: true

require 'spec_helper'
require 'puppet/type/dsc_resource'
require 'puppet/provider/dsc_resource/dsc_resource'

RSpec.describe 'dsc_resource provider' do
  let(:type) { Puppet::Type.type(:dsc_resource) }
  let(:provider_class) { type.provider(:dsc_resource) }

  let(:resource) do
    type.new(
      name: 'test_resource',
      ensure: :present,
      type: 'PSDesiredStateConfiguration/File',
      properties: {
        'DestinationPath' => '/tmp/test.txt',
        'Contents' => 'test',
      },
    )
  end

  let(:provider) { provider_class.new(resource) }

  before(:each) do
    allow(Puppet).to receive(:notice)
    allow(Puppet).to receive(:err)
    allow(Puppet).to receive(:debug)
  end

  describe '#dsc_binary_path' do
    context 'when dscv3_info fact is available' do
      context 'on Windows' do
        before(:each) do
          stub_platform('windows')
          allow(Facter).to receive(:value).with(:dscv3_info).and_return({ 'install_path' => 'C:/custom/dsc', 'version' => '3.0.1' })
        end

        it 'uses custom path from fact' do
          expect(provider.send(:dsc_binary_path)).to eq('C:/custom/dsc/dsc.exe')
        end
      end

      context 'on Linux' do
        before(:each) do
          stub_platform('Linux')
          allow(Facter).to receive(:value).with(:dscv3_info).and_return({ 'install_path' => '/custom/dsc', 'version' => '3.0.1' })
        end

        it 'uses custom path from fact' do
          expect(provider.send(:dsc_binary_path)).to eq('/custom/dsc/dsc')
        end
      end

      context 'on macOS' do
        before(:each) do
          stub_platform('Darwin')
          allow(Facter).to receive(:value).with(:dscv3_info).and_return({ 'install_path' => '/usr/local/custom/dsc', 'version' => '3.0.1' })
        end

        it 'uses custom path from fact' do
          expect(provider.send(:dsc_binary_path)).to eq('/usr/local/custom/dsc/dsc')
        end
      end
    end

    context 'when dscv3_info fact is not available' do
      before(:each) do
        allow(Facter).to receive(:value).with(:dscv3_info).and_return(nil)
      end

      context 'on Windows' do
        before(:each) do
          stub_platform('windows')
        end

        it 'raises error' do
          expect { provider.send(:dsc_binary_path) }.to raise_error(Puppet::Error, /DSC installation not found/)
        end
      end

      context 'on Linux' do
        before(:each) do
          stub_platform('Linux')
        end

        it 'raises error' do
          expect { provider.send(:dsc_binary_path) }.to raise_error(Puppet::Error, /DSC installation not found/)
        end
      end

      context 'on macOS' do
        before(:each) do
          stub_platform('Darwin')
        end

        it 'raises error' do
          expect { provider.send(:dsc_binary_path) }.to raise_error(Puppet::Error, /DSC installation not found/)
        end
      end
    end

  end

  describe '#dsc_binary_available?' do
    it 'checks if DSC binary exists' do
      allow(Facter).to receive(:value).with(:dscv3_info).and_return({ 'install_path' => '/opt/dsc', 'version' => '3.0.1' })
      allow(File).to receive(:exist?).with('/opt/dsc/dsc').and_return(true)
      stub_platform('Linux')
      expect(provider.send(:dsc_binary_available?)).to be true
    end

    it 'returns false if binary does not exist' do
      allow(Facter).to receive(:value).with(:dscv3_info).and_return({ 'install_path' => '/opt/dsc', 'version' => '3.0.1' })
      allow(File).to receive(:exist?).with('/opt/dsc/dsc').and_return(false)
      stub_platform('Linux')
      expect(provider.send(:dsc_binary_available?)).to be false
    end
  end

  describe '#generate_dsc_config' do
    let(:schema) { 'https://aka.ms/dsc/schemas/v3/bundled/config/document.json' }
    let(:properties) { { 'DestinationPath' => '/tmp/test.txt', 'Contents' => 'test' } }

    context 'without adapter' do
      it 'generates valid JSON configuration for direct DSC V3 resource' do
        json_output = provider.send(:generate_dsc_config, 'test_resource', 'PSDesiredStateConfiguration/File', schema, properties, nil)

        config = JSON.parse(json_output)
        expect(config['$schema']).to eq(schema)
        expect(config['resources']).to be_an(Array)
        expect(config['resources'].first['name']).to eq('test_resource')
        expect(config['resources'].first['type']).to eq('PSDesiredStateConfiguration/File')
        expect(config['resources'].first['properties']).to include('DestinationPath' => '/tmp/test.txt')
      end
    end

    context 'with adapter' do
      it 'generates valid JSON configuration wrapped in adapter structure' do
        json_output = provider.send(:generate_dsc_config, 'test_resource', 'PSDesiredStateConfiguration/WindowsFeature', schema, properties, 'Microsoft.Windows/WindowsPowerShell')

        config = JSON.parse(json_output)
        expect(config['$schema']).to eq(schema)
        expect(config['resources']).to be_an(Array)
        expect(config['resources'].first['name']).to eq('test_resource')
        expect(config['resources'].first['type']).to eq('Microsoft.Windows/WindowsPowerShell')
        expect(config['resources'].first['properties']['resources']).to be_an(Array)

        inner_resource = config['resources'].first['properties']['resources'].first
        expect(inner_resource['name']).to eq('test_resource')
        expect(inner_resource['type']).to eq('PSDesiredStateConfiguration/WindowsFeature')
        expect(inner_resource['properties']).to eq(properties)
      end
    end
  end

  describe '#parse_dsc_output' do
    it 'parses valid JSON output' do
      json_output = load_json_fixture('get_success.json')
      result = provider.send(:parse_dsc_output, json_output.to_json)

      expect(result).to be_a(Hash)
      expect(result['hadErrors']).to be false
      expect(result['results']).to be_an(Array)
    end

    it 'raises error on invalid JSON' do
      expect {
        provider.send(:parse_dsc_output, 'invalid json')
      }.to raise_error(Puppet::Error, %r{Failed to parse DSC output})
    end

    it 'raises error when DSC had errors' do
      json_output = load_json_fixture('error_resource_not_found.json')
      expect {
        provider.send(:parse_dsc_output, json_output.to_json)
      }.to raise_error(Puppet::Error, %r{DSC command failed})
    end
  end
end
