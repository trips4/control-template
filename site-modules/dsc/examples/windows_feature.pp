# Example: Managing Windows Features using DSC with adapter
#
# This example demonstrates using the adapter parameter to manage
# classic PowerShell DSC resources. Notice the 1:1 mapping between
# Puppet resources and DSC resources - each dsc_resource block
# represents exactly one DSC resource.
#
# The adapter parameter wraps the resource in the appropriate
# structure for classic DSC resources, while maintaining the
# same simple syntax as native DSC V3 resources.
#
# Note: ensure defaults to 'present'. To remove a resource, set
# 'Ensure' => 'Absent' in the properties hash, not in Puppet's ensure.

# Example 1: Install Telnet Client
dsc_resource { 'telnet_client':
  adapter    => 'Microsoft.Windows/WindowsPowerShell',
  type       => 'PSDesiredStateConfiguration/WindowsFeature',
  properties => {
    'Name'   => 'Telnet-Client',
    'Ensure' => 'Present',
  },
}

# Example 2: Install Web Server (IIS)
dsc_resource { 'web_server':
  adapter    => 'Microsoft.Windows/WindowsPowerShell',
  type       => 'PSDesiredStateConfiguration/WindowsFeature',
  properties => {
    'Name'   => 'Web-Server',
    'Ensure' => 'Present',
  },
}

# Example 3: Install ASP.NET 4.5
dsc_resource { 'aspnet45':
  adapter    => 'Microsoft.Windows/WindowsPowerShell',
  type       => 'PSDesiredStateConfiguration/WindowsFeature',
  properties => {
    'Name'   => 'Web-Asp-Net45',
    'Ensure' => 'Present',
  },
}

# Example 4: Configure Registry Setting
dsc_resource { 'disable_ie_esc':
  adapter    => 'Microsoft.Windows/WindowsPowerShell',
  type       => 'PSDesiredStateConfiguration/Registry',
  properties => {
    'Key'       => 'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}',
    'ValueName' => 'IsInstalled',
    'ValueData' => '0',
    'ValueType' => 'Dword',
    'Ensure'    => 'Present',
  },
}

# Example 5: Remove a Windows Feature (note Ensure in properties, not Puppet ensure)
dsc_resource { 'remove_telnet':
  adapter    => 'Microsoft.Windows/WindowsPowerShell',
  type       => 'PSDesiredStateConfiguration/WindowsFeature',
  properties => {
    'Name'   => 'Telnet-Client',
    'Ensure' => 'Absent',
  },
}
