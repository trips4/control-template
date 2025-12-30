# frozen_string_literal: true

require 'spec_helper'

describe 'dsc::psmodule' do
  let(:title) { 'PSDesiredStateConfiguration' }

  # Ensure dscv3_info fact is present (prerequisite for all tests)
  let(:facts) do
    {
      kernel: 'Linux',
      os: {
        'family' => 'Debian',
        'name' => 'Ubuntu',
        'architecture' => 'x86_64',
      },
      dscv3_info: {
        'version' => '3.0.0',
        'path' => '/usr/local/bin/dsc',
      },
    }
  end

  # Pre-declare the dsc class that psmodule requires
  let(:pre_condition) { 'include dsc' }

  context 'with default parameters (ensure => present)' do
    let(:params) do
      {
        version: '2.0.7',
      }
    end

    it { is_expected.to compile.with_all_deps }

    it 'creates exec with pwsh provider for installation' do
      is_expected.to contain_exec('install_psmodule_PSDesiredStateConfiguration_2.0.7')
        .with_provider('pwsh')
      is_expected.to contain_exec('install_psmodule_PSDesiredStateConfiguration_2.0.7')
        .with_command(%r{Install-Module})
      is_expected.to contain_exec('install_psmodule_PSDesiredStateConfiguration_2.0.7')
        .with_unless(%r{Get-InstalledModule})
    end
  end

  context 'when module is already installed (idempotency test)' do
    let(:params) do
      {
        ensure: 'present',
        version: '2.0.7',
      }
    end

    it { is_expected.to compile.with_all_deps }

    it 'creates exec with unless check for idempotency' do
      is_expected.to contain_exec('install_psmodule_PSDesiredStateConfiguration_2.0.7')
        .with_unless(%r{Get-InstalledModule})
    end
  end

  context 'with invalid version format' do
    let(:params) do
      {
        version: 'latest',
      }
    end

    it { is_expected.to compile.and_raise_error(%r{Parameter 'version' must match semantic versioning format}) }
  end

  context 'with invalid version format (missing patch)' do
    let(:params) do
      {
        version: '2.0',
      }
    end

    it { is_expected.to compile.and_raise_error(%r{Parameter 'version' must match semantic versioning format}) }
  end

  context 'without dscv3_info fact (prerequisite check)' do
    let(:facts) do
      {
        kernel: 'Linux',
        os: {
          'family' => 'Debian',
          'name' => 'Ubuntu',
          'architecture' => 'x86_64',
        },
      }
    end

    let(:params) do
      {
        version: '2.0.7',
      }
    end

    it { is_expected.to compile.and_raise_error(%r{DSC v3 must be installed}) }
  end

  context 'with module dependencies' do
    let(:params) do
      {
        version: '9.0.0',
      }
    end

    let(:title) { 'NetworkingDsc' }

    it { is_expected.to compile.with_all_deps }

    it 'creates exec that will handle dependencies automatically' do
      # PowerShell Install-Module handles dependencies automatically
      is_expected.to contain_exec('install_psmodule_NetworkingDsc_9.0.0')
        .with_command(%r{Install-Module})
    end
  end

  context 'with custom repository' do
    let(:params) do
      {
        version: '2.0.7',
        repository: 'CompanyInternal',
      }
    end

    it { is_expected.to compile.with_all_deps }

    it 'passes repository parameter to PowerShell template' do
      is_expected.to contain_exec('install_psmodule_PSDesiredStateConfiguration_2.0.7')
        .with_command(%r{CompanyInternal})
    end
  end

  context 'with ensure => absent' do
    let(:params) do
      {
        ensure: 'absent',
        version: '2.0.7',
      }
    end

    it { is_expected.to compile.with_all_deps }

    it {
      is_expected.to contain_exec('install_psmodule_PSDesiredStateConfiguration_2.0.7')
        .with_command(%r{Uninstall-Module})
    }
  end

  context 'when module already absent (idempotency test)' do
    let(:params) do
      {
        ensure: 'absent',
        version: '2.0.7',
      }
    end

    it { is_expected.to compile.with_all_deps }

    it 'creates exec with unless check for idempotency' do
      is_expected.to contain_exec('install_psmodule_PSDesiredStateConfiguration_2.0.7')
        .with_unless(%r{Get-InstalledModule})
    end
  end

  context 'with local source file' do
    let(:params) do
      {
        version: '1.0.0',
        source: '/mnt/packages/OfflineModule.1.0.0.nupkg',
      }
    end

    let(:title) { 'OfflineModule' }

    it { is_expected.to compile.with_all_deps }

    it 'passes source parameter to PowerShell template' do
      is_expected.to contain_exec('install_psmodule_OfflineModule_1.0.0')
        .with_command(%r{/mnt/packages/OfflineModule})
    end
  end

  context 'with both repository and source (mutual exclusivity)' do
    let(:params) do
      {
        version: '2.0.7',
        repository: 'PSGallery',
        source: '/tmp/test.nupkg',
      }
    end

    it { is_expected.to compile.and_raise_error(%r{Parameters repository and source are mutually exclusive}) }
  end
end
