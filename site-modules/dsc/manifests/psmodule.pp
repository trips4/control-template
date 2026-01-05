# @summary Manage PowerShell modules containing DSC resources
#
# This defined type enables declarative management of PowerShell modules
# that contain DSC resources. It supports installation from PowerShell Gallery,
# custom repositories, or local .nupkg files, as well as module removal.
#
# @param ensure
#   Whether the module should be present or absent.
#   Default: 'present'
#
# @param version
#   Exact semantic version of the module to install (format: X.Y.Z).
#   This parameter is required. The 'latest' keyword is not supported.
#   Example: '2.0.7'
#
# @param repository
#   PowerShell repository name to install from (e.g., 'PSGallery', 'CompanyInternal').
#   Defaults to 'PSGallery' if not specified.
#   This parameter is mutually exclusive with the 'source' parameter.
#
# @param source
#   Local file path to a .nupkg file for offline installation.
#   This parameter is mutually exclusive with the 'repository' parameter.
#   The file must exist and have a .nupkg extension.
#   Example: '/mnt/packages/MyModule.1.0.0.nupkg'
#
# @example Basic installation from PowerShell Gallery
#   dsc::psmodule { 'PSDesiredStateConfiguration':
#     ensure  => present,
#     version => '2.0.7',
#   }
#
# @example Installation from custom repository
#   dsc::psmodule { 'CompanyDSCResources':
#     ensure     => present,
#     version    => '3.1.0',
#     repository => 'CompanyInternal',
#   }
#
# @example Installation from local file (offline scenario)
#   dsc::psmodule { 'OfflineModule':
#     ensure  => present,
#     version => '1.0.0',
#     source  => '/mnt/packages/OfflineModule.1.0.0.nupkg',
#   }
#
# @example Module removal
#   dsc::psmodule { 'UnwantedModule':
#     ensure  => absent,
#     version => '1.5.2',
#   }
#
# @example Module upgrade (change version and apply)
#   dsc::psmodule { 'NetworkingDsc':
#     ensure  => present,
#     version => '9.1.0',  # Changed from '9.0.0' - triggers upgrade
#   }
#
define dsc::psmodule (
  String[1] $version,
  Enum['present', 'absent'] $ensure = 'present',
  Optional[String[1]] $repository = undef,
  Optional[Stdlib::Absolutepath] $source = undef,
) {
  # Prerequisite check: DSC v3 must be installed
  unless $facts['dscv3_info'] {
    fail('DSC v3 must be installed before managing PowerShell modules. Please ensure the dsc class is applied first.')
  }

  # Validate version format (must be semantic version X.Y.Z)
  unless $version =~ /^\d+\.\d+\.\d+$/ {
    fail("Parameter 'version' must match semantic versioning format (X.Y.Z), got: ${version}")
  }

  # Validate mutual exclusivity of repository and source
  if $repository and $source {
    fail('Parameters repository and source are mutually exclusive. Specify only one.')
  }

  # Generate PowerShell scripts from templates (module name is $title)
  $check_script = epp('dsc/psmodule_check.ps1.epp', {
      'module_name' => $title,
      'version'     => $version,
      'ensure'      => $ensure,
  })

  $manage_script = epp('dsc/psmodule_manage.ps1.epp', {
      'module_name' => $title,
      'version'     => $version,
      'ensure'      => $ensure,
      'repository'  => $repository,
      'source'      => $source,
  })

  # Execute PowerShell module management using pwsh provider
  # The provider handles PowerShell 7.2+ (pwsh) invocation with proper flags
  # The 'unless' parameter ensures idempotency by checking current state first
  exec { "install_psmodule_${title}_${version}":
    command  => $manage_script,
    unless   => "${check_script}; exit \$LASTEXITCODE",
    provider => pwsh,
    require  => Class['dsc'],
  }
}
