# frozen_string_literal: true

# Traditional Puppet type for DSC V3 resources
Puppet::Type.newtype(:dsc_resource) do
  @doc = <<-DOC
    @summary
      Manages a Microsoft DSC V3 resource through the DSC CLI.

    @example Basic file resource management
      dsc_resource { 'example_file':
        type       => 'PSDesiredStateConfiguration/File',
        properties => {
          'DestinationPath' => 'C:/Windows/Temp/example.txt',
          'Contents'        => 'Hello from Puppet!',
          'Ensure'          => 'Present',
        },
      }

    @example Cross-platform configuration
      dsc_resource { 'config_file':
        type       => 'PSDesiredStateConfiguration/File',
        properties => {
          'DestinationPath' => $facts['os']['family'] ? {
            'windows' => 'C:/config.txt',
            default   => '/etc/config.txt',
          },
          'Contents'        => template('mymodule/config.erb'),
        },
      }
  DOC

  ensurable do
    desc <<-DESC
      Whether the DSC resource configuration should be managed by Puppet.

      This should always be 'present' for active DSC resource management.
      To remove or change the state of a DSC resource, modify the properties
      (e.g., set 'Ensure' => 'Absent' in the resource's properties hash).

      The 'absent' value is not supported for DSC V3 resources.
    DESC

    defaultto :present

    newvalue(:present) do
      provider.create
    end

    newvalue(:absent) do
      raise Puppet::Error, <<-ERROR
        Managing DSC V3 resources with Puppet requires ensure => present.
        To remove a DSC configuration, pass the removal state in the resource properties.
        For example, to uninstall a Windows Feature:
          dsc_resource { 'my_feature':
            ensure     => present,
            type       => 'PSDesiredStateConfiguration/WindowsFeature',
            properties => {
              'Name'   => 'Feature-Name',
              'Ensure' => 'Absent',
            },
          }
      ERROR
    end
  end

  newparam(:name, namevar: true) do
    desc 'The title of the resource (for Puppet identification).'
  end

  newparam(:type) do
    desc 'The fully qualified DSC resource name (e.g., "Microsoft.Windows/Registry" or "PSDesiredStateConfiguration/File").'
    isrequired
  end

  newparam(:schema) do
    desc 'The JSON schema URI for the DSC configuration document. Defaults to the latest DSC V3 bundled schema.'
    defaultto 'https://aka.ms/dsc/schemas/v3/bundled/config/document.json'
  end

  newparam(:adapter) do
    desc 'Optional adapter resource type (e.g., "Microsoft.Windows/WindowsPowerShell") to wrap classic PowerShell DSC resources.'
  end

  newparam(:properties) do
    desc 'A hash of properties to pass to the DSC resource. Property names and values depend on the specific DSC resource.'
    defaultto {}

    validate do |value|
      unless value.is_a?(Hash)
        raise ArgumentError, 'properties must be a Hash'
      end
    end

    munge do |value|
      # Ensure all keys are strings for consistency
      value.transform_keys(&:to_s)
    end
  end

  # Autorequire the dsc class to ensure DSC v3 is installed before using resources
  autorequire(:class) do
    ['dsc']
  end

  # Autorequire dsc::psmodule resources based on the DSC resource type
  # For example, 'PSDesiredStateConfiguration/File' autorequires dsc::psmodule['PSDesiredStateConfiguration']
  autorequire(:dsc__psmodule) do
    requirements = []

    if self[:type]
      # Extract module name from type (e.g., 'PSDesiredStateConfiguration/File' -> 'PSDesiredStateConfiguration')
      parts = self[:type].split('/')
      if parts.length >= 2
        module_name = parts[0]
        # Only autorequire if it's a PowerShell module (not native DSC v3 resources like 'Microsoft.Windows')
        # Classic DSC resources typically come from PowerShell modules with names like:
        # - PSDesiredStateConfiguration
        # - ComputerManagementDsc
        # - NetworkingDsc
        # - etc.
        #
        # Native DSC v3 resources use namespaces like:
        # - Microsoft.Windows
        # - Microsoft.MacOS
        #
        # We autorequire the PowerShell module for any type that looks like a module name
        requirements << module_name unless module_name.start_with?('Microsoft.')
      end
    end

    requirements
  end
end
