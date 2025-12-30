# Changelog

All notable changes to this project will be documented in this file.

## Release 0.1.0 (2025-12-17)

Initial release of puppetlabs-dsc module for managing Microsoft DSC V3 resources through Puppet.

**Features**

* **DSC V3 Integration**: Complete integration with Microsoft DSC V3 CLI
  - `dsc_resource` type for managing any DSC resource
  - Cross-platform support (Windows, Linux, macOS)
  - Idempotent resource management with DSC test/set operations
  - Support for both classic DSC resources and native DSC v3 resources

* **DSC Installation Management**: `dsc` class for automated DSC v3 installation
  - Automatic download and installation of DSC v3 binary
  - Configurable installation directory
  - Version pinning support
  - Visual C++ Runtime dependency management (Windows)
  - PATH configuration for easy CLI access

* **PowerShell Module Management**: `dsc::psmodule` defined type for managing DSC resource modules
  - Install/remove PowerShell modules from PSGallery or custom repositories
  - Version pinning and upgrade support
  - Offline installation support via local .nupkg files
  - Automatic cache invalidation for fact updates

* **Autorequire**: Automatic dependency management
  - `dsc_resource` automatically depends on `Class['dsc']`
  - `dsc_resource` automatically depends on matching `Dsc::Psmodule` resources
  - No explicit `require` statements needed in manifests

* **Facts**: Custom facts for DSC environment information
  - `dscv3_info`: Installation path, version, and platform details
  - Enables provider to automatically discover DSC installation

* **Adapter Support**: Full support for classic PowerShell DSC resources
  - Use `adapter => 'Microsoft.Windows/WindowsPowerShell'` for classic resources
  - Native DSC v3 resources work without adapter

**Requirements**

* Puppet Agent >= 8.0.0
* PowerShell 7.2 or later
* puppetlabs/powershell >= 6.0.0
* puppetlabs/pwshlib >= 1.0.0
* puppetlabs/stdlib >= 4.25.0

**Known Issues**

* Two Puppet runs required on first install (first run installs DSC, second run uses it)
* DSC resource discovery requires PowerShell modules to be in `$env:PSModulePath`
* Limited to DSC v3 resources (DSC v2 resources require adapter parameter)
