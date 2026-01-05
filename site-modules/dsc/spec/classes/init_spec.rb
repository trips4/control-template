# frozen_string_literal: true

require 'spec_helper'

describe 'dsc' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
      end

      context 'with specific version' do
        let(:params) { { version: 'v3.1.2' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_exec('download_dsc').with_command(%r{https://github\.com/PowerShell/DSC/releases/download/v3\.1\.2/DSC-}) }
      end

      context 'with version set to latest' do
        let(:params) { { version: 'latest' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_exec('download_dsc').with_command(%r{https://github\.com/PowerShell/DSC/releases/download/v3\.1\.2/DSC-3\.1\.2-}) }
      end

      context 'with manage_path set to false' do
        let(:params) { { manage_path: false } }

        it { is_expected.to compile.with_all_deps }
      end
    end
  end

  # Architecture detection tests
  context 'on x86_64 architecture' do
    let(:facts) do
      {
        kernel: 'Linux',
        os: {
          family: 'RedHat',
          name: 'CentOS',
          release: { major: '8' },
          architecture: 'x86_64',
        },
      }
    end

    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_exec('download_dsc').with_command(%r{DSC-3\.1\.2-x86_64-unknown-linux-gnu\.tar\.gz}) }
  end

  context 'on aarch64 architecture' do
    let(:facts) do
      {
        kernel: 'Linux',
        os: {
          family: 'RedHat',
          name: 'CentOS',
          release: { major: '8' },
          architecture: 'aarch64',
        },
      }
    end

    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_exec('download_dsc').with_command(%r{DSC-3\.1\.2-aarch64-unknown-linux-gnu\.tar\.gz}) }
  end

  context 'on arm64 architecture (macOS)' do
    let(:facts) do
      {
        kernel: 'Darwin',
        os: {
          family: 'Darwin',
          name: 'Darwin',
          release: { major: '23' },
          architecture: 'arm64',
        },
      }
    end

    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_exec('download_dsc').with_command(%r{DSC-3\.1\.2-aarch64-apple-darwin\.tar\.gz}) }
  end

  # Failure cases
  context 'on unsupported architecture' do
    let(:facts) do
      {
        kernel: 'Linux',
        os: {
          family: 'RedHat',
          name: 'CentOS',
          release: { major: '8' },
          architecture: 'i386',
        },
      }
    end

    it { is_expected.to compile.and_raise_error(%r{Unsupported architecture: i386}) }
  end

  context 'on unsupported operating system' do
    let(:facts) do
      {
        kernel: 'SunOS',
        os: {
          family: 'Solaris',
          name: 'Solaris',
          release: { major: '11' },
          architecture: 'x86_64',
        },
      }
    end

    it { is_expected.to compile.and_raise_error(%r{Unsupported kernel: SunOS}) }
  end

  # Binary validation tests (Phase 2: Test-First Development)
  # These tests verify that the DSC binary is validated after installation
  context 'binary validation' do
    let(:facts) do
      {
        kernel: 'Linux',
        os: {
          family: 'RedHat',
          name: 'CentOS',
          release: { major: '8' },
          architecture: 'x86_64',
        },
      }
    end

    context 'on Linux' do
      it 'validates DSC binary after installation' do
        is_expected.to contain_exec('validate_dsc_binary')
          .with(
            command: %r{/opt/dsc/dsc --version},
            require: 'File[/opt/dsc/dsc]',
          )
      end

      it 'validation exec should run unless DSC is already validated' do
        is_expected.to contain_exec('validate_dsc_binary')
          .with(
            unless: %r{/opt/dsc/dsc --version},
          )
      end
    end

    context 'on Windows' do
      let(:facts) do
        {
          kernel: 'windows',
          os: {
            family: 'windows',
            name: 'windows',
            release: { major: '10' },
            architecture: 'x86_64',
            windows: {
              system32: 'C:\\Windows\\system32',
            },
          },
        }
      end

      it 'validates DSC binary after installation' do
        is_expected.to contain_exec('validate_dsc_binary')
          .with(
            command: %r{Test-Path.*C:/Program Files/DSC/dsc\.exe},
            provider: 'pwsh',
            require: 'Exec[extract_dsc]',
          )
      end
    end
  end

  # Enhanced error messaging tests (Phase 2: Test-First Development)
  # These tests verify clear error messages for common failure scenarios
  context 'error handling' do
    context 'with unsupported architecture' do
      let(:facts) do
        {
          kernel: 'Linux',
          os: {
            family: 'RedHat',
            name: 'CentOS',
            release: { major: '8' },
            architecture: 'i386',
          },
        }
      end

      it 'fails with clear architecture error message' do
        is_expected.to compile.and_raise_error(
          %r{Unsupported architecture: i386\. DSC requires x86_64 or aarch64/arm64 architecture},
        )
      end
    end

    context 'with unsupported kernel' do
      let(:facts) do
        {
          kernel: 'FreeBSD',
          os: {
            family: 'FreeBSD',
            name: 'FreeBSD',
            release: { major: '13' },
            architecture: 'x86_64',
          },
        }
      end

      it 'fails with clear platform error message' do
        is_expected.to compile.and_raise_error(
          %r{Unsupported kernel: FreeBSD\. DSC requires Windows, Linux, or macOS},
        )
      end
    end

    context 'default kernel failure' do
      let(:facts) do
        {
          kernel: 'AIX',
          os: {
            family: 'AIX',
            name: 'AIX',
            release: { major: '7' },
            architecture: 'x86_64',
          },
        }
      end

      it 'fails with clear default platform error message' do
        is_expected.to compile.and_raise_error(
          %r{Unsupported kernel: AIX\. DSC requires Windows, Linux, or macOS},
        )
      end
    end
  end
end
