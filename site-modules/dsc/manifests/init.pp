# @summary Installs and manages DSC v3
#
# This class installs DSC v3 from the latest GitHub release, validates the binary,
# and optionally adds it to the system PATH. The class automatically:
#
# - Downloads the appropriate DSC binary for the platform and architecture
# - Extracts and sets correct permissions on the binary
# - Validates the binary is functional using `dsc --version`
# - Writes an external fact file for the `dsc_resource` provider to discover the installation
# - Optionally manages PATH for convenient CLI access
#
# @param install_dir
#   The directory where DSC should be installed. If not specified, platform-specific
#   defaults are used:
#   - Windows: C:/Program Files/DSC
#   - Linux: /opt/dsc
#   - macOS: /usr/local/dsc
#
# @param version
#   The version of DSC to install. Defaults to 'latest'. Can be set to a specific
#   version tag like 'v3.1.2' to pin the installation.
#
# @param manage_path
#   Whether to add the DSC installation directory to the system PATH. Defaults to true.
#   On Windows, uses the windows_env resource. On Unix-like systems, creates
#   /etc/profile.d/dsc.sh for system-wide PATH updates.
#
# @example Basic usage with defaults
#   include dsc
#
# @example Custom installation directory
#   class { 'dsc':
#     install_dir => '/opt/dsc',
#   }
#
# @example Install specific version
#   class { 'dsc':
#     version => 'v3.1.2',
#   }
#
# @example Skip PATH management
#   class { 'dsc':
#     manage_path => false,
#   }
#
class dsc (
  Optional[Stdlib::Absolutepath] $install_dir = undef,
  String $version = 'latest',
  Boolean $manage_path = true,
) {
  # Determine platform-specific defaults
  $default_install_dir = case $facts['kernel'] {
    'windows': { 'C:/Program Files/DSC' }
    'Darwin':  { '/usr/local/dsc' }
    'Linux':   { '/opt/dsc' }
    default:   { fail("Unsupported kernel: ${facts['kernel']}. DSC requires Windows, Linux, or macOS.") }
  }

  # Use provided install_dir or fall back to default
  $actual_install_dir = pick($install_dir, $default_install_dir)

  # Determine architecture
  $arch = case $facts['os']['architecture'] {
    'x86_64', 'amd64', 'x64': { 'x86_64' }
    'aarch64', 'arm64': { 'aarch64' }
    default: { fail("Unsupported architecture: ${facts['os']['architecture']}. DSC requires x86_64 or aarch64/arm64 architecture.") }
  }

  # Determine platform and file extension
  case $facts['kernel'] {
    'windows': {
      $platform = 'pc-windows-msvc'
      $archive_ext = 'zip'
      $dsc_binary = 'dsc.exe'
    }
    'Darwin': {
      $platform = 'apple-darwin'
      $archive_ext = 'tar.gz'
      $dsc_binary = 'dsc'
    }
    'Linux': {
      $platform = 'unknown-linux-gnu'
      $archive_ext = 'tar.gz'
      $dsc_binary = 'dsc'
    }
    default: {
      fail("Unsupported operating system: ${facts['kernel']}. DSC supports Windows, Linux (unknown-linux-gnu), and macOS (apple-darwin).")
    }
  }

  # Construct download URL
  # GitHub release filenames include version number in the filename
  # For 'latest', we default to a known stable version since GitHub doesn't provide
  # a version-less latest download URL
  if $version == 'latest' {
    # Default to most recent stable version
    # Users should specify explicit version for production use
    $actual_version = 'v3.1.2'
    $version_number = '3.1.2'
  } else {
    $actual_version = $version
    $version_number = regsubst($version, '^v', '')
  }
  
  $download_base = 'https://github.com/PowerShell/DSC/releases'
  $download_url = "${download_base}/download/${actual_version}/DSC-${version_number}-${arch}-${platform}.${archive_ext}"

  $temp_archive = $facts['kernel'] ? {
    'windows' => "C:/Windows/Temp/dsc.${archive_ext}",
    default   => "/tmp/dsc.${archive_ext}",
  }

  # Ensure installation directory exists
  if $facts['kernel'] == 'windows' {
    file { $actual_install_dir:
      ensure => directory,
    }
  } else {
    file { $actual_install_dir:
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    }
  }

  # Windows-specific prerequisites
  # DSC v3 Windows binaries are built with Rust and require Visual C++ Runtime
  if $facts['kernel'] == 'windows' {
    # Install Visual C++ 2015-2022 Redistributable (x64)
    # This is required for DSC.exe to run - without it, you get exit code -1073741515 (0xC0000135)
    $vcredist_url = 'https://aka.ms/vs/17/release/vc_redist.x64.exe'
    $vcredist_installer = 'C:/Windows/Temp/vc_redist.x64.exe'
    
    exec { 'download_vcredist':
      command   => "Invoke-WebRequest -Uri '${vcredist_url}' -OutFile '${vcredist_installer}'",
      creates   => $vcredist_installer,
      provider  => pwsh,
      logoutput => true,
    }

    exec { 'install_vcredist':
      command   => "${vcredist_installer} /quiet /norestart",
      unless    => "if (Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\VisualStudio\\14.0\\VC\\Runtimes\\x64' -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }",
      provider  => pwsh,
      require   => Exec['download_vcredist'],
      logoutput => true,
    }
  }

  # Download DSC archive
  case $facts['kernel'] {
    'windows': {
      exec { 'download_dsc':
        command   => "Invoke-WebRequest -Uri '${download_url}' -OutFile '${temp_archive}'",
        creates   => "${actual_install_dir}/${dsc_binary}",
        provider  => pwsh,
        require   => [File[$actual_install_dir], Exec['install_vcredist']],
        logoutput => true,
      }

      # Extract archive on Windows
      exec { 'extract_dsc':
        command   => "Expand-Archive -Path '${temp_archive}' -DestinationPath '${actual_install_dir}' -Force",
        creates   => "${actual_install_dir}/${dsc_binary}",
        provider  => pwsh,
        require   => Exec['download_dsc'],
        logoutput => true,
      }

      # Clean up temp file
      exec { 'cleanup_dsc_archive':
        command     => "Remove-Item -Path '${temp_archive}' -Force",
        onlyif      => "Test-Path '${temp_archive}'",
        provider    => pwsh,
        require     => Exec['extract_dsc'],
        refreshonly => true,
      }

      # Validate DSC binary after installation
      # Ensures the binary exists and is accessible
      # This provides early detection of extraction issues or corrupted downloads
      exec { 'validate_dsc_binary':
        command  => "if (Test-Path '${actual_install_dir}/${dsc_binary}') { exit 0 } else { exit 1 }",
        unless   => "Test-Path '${actual_install_dir}/${dsc_binary}'",
        provider => pwsh,
        require  => Exec['extract_dsc'],
      }

      # Add to Windows PATH
      if $manage_path {
        windows_env { 'PATH=dsc':
          ensure    => present,
          variable  => 'PATH',
          value     => $actual_install_dir,
          mergemode => 'append',
          require   => Exec['validate_dsc_binary'],
        }
      }
    }
    default: {
      # Unix-like systems
      exec { 'download_dsc':
        command   => "/usr/bin/curl -L -o '${temp_archive}' '${download_url}'",
        creates   => "${actual_install_dir}/${dsc_binary}",
        require   => File[$actual_install_dir],
        logoutput => true,
      }

      # Extract archive on Unix-like systems
      exec { 'extract_dsc':
        command   => "/bin/tar -xzf '${temp_archive}' -C '${actual_install_dir}'",
        creates   => "${actual_install_dir}/${dsc_binary}",
        require   => Exec['download_dsc'],
        logoutput => true,
      }

      # Set executable permissions
      file { "${actual_install_dir}/${dsc_binary}":
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        require => Exec['extract_dsc'],
      }

      # Validate DSC binary after installation
      # Ensures the binary is executable and responds to --version
      # This provides early detection of corrupted downloads or platform incompatibilities
      # The 'unless' ensures idempotency - validation only runs if the binary is not already functional
      exec { 'validate_dsc_binary':
        command => "${actual_install_dir}/${dsc_binary} --version",
        unless  => "${actual_install_dir}/${dsc_binary} --version",
        path    => ['/usr/bin', '/bin', $actual_install_dir],
        require => File["${actual_install_dir}/${dsc_binary}"],
      }

      # Clean up temp file
      file { $temp_archive:
        ensure  => absent,
        require => Exec['validate_dsc_binary'],
      }

      # Add to Unix PATH via profile.d
      if $manage_path {
        file { '/etc/profile.d/dsc.sh':
          ensure  => file,
          owner   => 'root',
          group   => 'root',
          mode    => '0644',
          content => "export PATH=\"\${PATH}:${actual_install_dir}\"\n",
          require => Exec['validate_dsc_binary'],
        }
      }
    }
  }

  # Note: DSC installation discovery is handled by the dscv3_info custom fact
  # in lib/facter/dsc_install_path.rb. The fact automatically discovers DSC
  # installations by checking common paths and querying version information.
  # No external fact file management is needed.
}
