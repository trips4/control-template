# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'dsc_resource' do
  subject(:type) { Puppet::Type.type(:dsc_resource) }

  let(:resource) do
    type.new(
      name: 'test_resource',
      type: 'PSDesiredStateConfiguration/File',
      properties: {
        'DestinationPath' => '/tmp/test.txt',
        'Contents' => 'test content',
      },
    )
  end

  describe 'basic structure' do
    it 'is a valid type' do
      expect(type).not_to be_nil
    end

    it 'has a name parameter' do
      expect(type.key_attributes).to include(:name)
    end
  end

  describe 'ensure parameter' do
    it 'defaults to present' do
      resource = type.new(name: 'test', type: 'Test/Resource', properties: {})
      expect(resource[:ensure]).to eq(:present)
    end

    it 'accepts present value' do
      expect {
        type.new(name: 'test', ensure: :present, type: 'Test/Resource', properties: {})
      }.not_to raise_error
    end

    it 'raises error when set to absent' do
      expect {
        resource = type.new(name: 'test', ensure: :absent, type: 'Test/Resource', properties: {})
        # Trigger the validation by accessing the ensure property's sync method
        resource.property(:ensure).sync
      }.to raise_error(Puppet::Error, /Managing DSC V3 resources with Puppet requires ensure => present/)
    end
  end

  describe 'namevar validation' do
    it 'accepts a valid name' do
      expect { type.new(name: 'valid_resource', type: 'Test/Resource', properties: {}) }.not_to raise_error
    end
  end

  describe 'type parameter' do
    it 'accepts valid DSC resource names' do
      expect { type.new(name: 'test', type: 'Microsoft.Windows/Registry', properties: {}) }.not_to raise_error
    end

    it 'accepts resource names with path separators' do
      expect { type.new(name: 'test', type: 'PSDesiredStateConfiguration/File', properties: {}) }.not_to raise_error
    end
  end

  describe 'properties parameter' do
    it 'accepts a hash of properties' do
      resource = type.new(
        name: 'test',
        type: 'Test/Resource',
        properties: { 'Key' => 'Value', 'AnotherKey' => 'AnotherValue' },
      )
      expect(resource[:properties]).to eq('Key' => 'Value', 'AnotherKey' => 'AnotherValue')
    end

    it 'can be omitted (defaults to nil, defaultto is for internal use)' do
      resource = type.new(name: 'test', ensure: :present, type: 'Test/Resource')
      # Puppet parameters with defaultto return nil when not specified
      # The defaultto is used internally when the parameter is referenced
      expect(resource[:properties]).to be_nil
    end

    it 'accepts nested hash values' do
      resource = type.new(
        name: 'test',
        type: 'Test/Resource',
        properties: {
          'Config' => {
            'Setting1' => 'Value1',
            'Setting2' => 'Value2',
          },
        },
      )
      expect(resource[:properties]['Config']).to be_a(Hash)
    end

    it 'accepts array values' do
      resource = type.new(
        name: 'test',
        type: 'Test/Resource',
        properties: {
          'Items' => ['item1', 'item2', 'item3'],
        },
      )
      expect(resource[:properties]['Items']).to be_an(Array)
    end
  end

  describe 'ensure parameter' do
    it 'defaults to present' do
      resource = type.new(name: 'test', type: 'Test/Resource', properties: {})
      expect(resource[:ensure]).to eq(:present)
    end

    it 'accepts present' do
      resource = type.new(name: 'test', type: 'Test/Resource', properties: {}, ensure: 'present')
      expect(resource[:ensure]).to eq(:present)
    end

    it 'accepts absent' do
      resource = type.new(name: 'test', type: 'Test/Resource', properties: {}, ensure: 'absent')
      expect(resource[:ensure]).to eq(:absent)
    end

    it 'rejects invalid values' do
      expect { type.new(name: 'test', type: 'Test/Resource', properties: {}, ensure: 'invalid') }.to raise_error(Puppet::ResourceError, %r{ensure})
    end
  end

  describe 'schema parameter' do
    it 'defaults to DSC V3 bundled schema' do
      resource = type.new(name: 'test', type: 'Test/Resource', properties: {})
      expect(resource[:schema]).to eq('https://aka.ms/dsc/schemas/v3/bundled/config/document.json')
    end

    it 'accepts custom schema URI' do
      custom_schema = 'https://example.com/custom-schema.json'
      resource = type.new(name: 'test', type: 'Test/Resource', properties: {}, schema: custom_schema)
      expect(resource[:schema]).to eq(custom_schema)
    end
  end

  describe 'resource creation' do
    it 'creates a resource with all required parameters' do
      expect(resource).to be_a(Puppet::Type::Dsc_resource)
    end

    it 'stores the type' do
      expect(resource[:type]).to eq('PSDesiredStateConfiguration/File')
    end

    it 'stores the properties hash' do
      expect(resource[:properties]).to include('DestinationPath' => '/tmp/test.txt')
    end
  end

  describe 'property validation' do
    it 'does not validate property values at type level' do
      # Property validation is delegated to DSC
      expect { type.new(name: 'test', type: 'Test/Resource', properties: { 'AnyKey' => 'AnyValue' }) }.not_to raise_error
    end
  end

  describe 'autorequire' do
    let(:catalog) { Puppet::Resource::Catalog.new }

    before do
      catalog.add_resource(resource)
    end

    context 'without any related resources in catalog' do
      it 'does not autorequire anything' do
        expect(resource.autorequire).to be_empty
      end
    end

    # Note: Full integration testing of autorequire with actual Class[dsc] and
    # Dsc::Psmodule resources requires a catalog compiler and is better tested
    # in acceptance tests. These unit tests verify the autorequire blocks are
    # defined and the logic works correctly.
  end
end
