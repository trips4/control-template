# frozen_string_literal: true

require 'spec_helper'
require 'facter'

describe 'dscv3_info fact' do
  before :each do
    Facter.clear
    Facter.clear_messages
    # Allow Facter internals to work
    allow(Facter::Core::Execution).to receive(:execute).and_call_original
    allow(File).to receive(:exist?).and_call_original
  end

  # Load the custom fact
  before :all do
    fact_path = File.expand_path('../../../lib/facter/dsc_install_path.rb', __dir__)
    load fact_path
  end

  context 'on Windows' do
    let(:dsc_binary) { 'C:/Program Files/DSC/dsc.exe' }

    before :each do
      allow(Facter).to receive(:value).and_call_original
      allow(Facter).to receive(:value).with(:kernel).and_return('windows')
    end

    it 'returns structured fact when DSC binary exists and version succeeds' do
      allow(File).to receive(:exist?).with('C:/Program Files/DSC/dsc.exe').and_return(true)
      allow(File).to receive(:exist?).with('C:/ProgramData/Puppetlabs/DSC/dsc.exe').and_return(false)
      allow(Facter::Core::Execution).to receive(:execute).with("#{dsc_binary} --version 2>&1", on_fail: nil).and_return('dsc 3.0.1')

      result = Facter.value(:dscv3_info)
      expect(result).to be_a(Hash)
      expect(result['install_path']).to eq('C:/Program Files/DSC')
      expect(result['version']).to eq('3.0.1')
    end

    it 'returns unknown version when version command fails' do
      allow(File).to receive(:exist?).with('C:/Program Files/DSC/dsc.exe').and_return(true)
      allow(File).to receive(:exist?).with('C:/ProgramData/Puppetlabs/DSC/dsc.exe').and_return(false)
      allow(Facter::Core::Execution).to receive(:execute).with("#{dsc_binary} --version 2>&1", on_fail: nil).and_return(nil)

      result = Facter.value(:dscv3_info)
      expect(result).to be_a(Hash)
      expect(result['install_path']).to eq('C:/Program Files/DSC')
      expect(result['version']).to eq('unknown')
    end

    it 'checks alternative path when primary does not exist' do
      alt_binary = 'C:/ProgramData/Puppetlabs/DSC/dsc.exe'
      allow(File).to receive(:exist?).with('C:/Program Files/DSC/dsc.exe').and_return(false)
      allow(File).to receive(:exist?).with(alt_binary).and_return(true)
      allow(Facter::Core::Execution).to receive(:execute).with("#{alt_binary} --version 2>&1", on_fail: nil).and_return('3.1.2')

      result = Facter.value(:dscv3_info)
      expect(result).to be_a(Hash)
      expect(result['install_path']).to eq('C:/ProgramData/Puppetlabs/DSC')
      expect(result['version']).to eq('3.1.2')
    end

    it 'returns nil when no DSC binary found' do
      allow(File).to receive(:exist?).with('C:/Program Files/DSC/dsc.exe').and_return(false)
      allow(File).to receive(:exist?).with('C:/ProgramData/Puppetlabs/DSC/dsc.exe').and_return(false)

      expect(Facter.value(:dscv3_info)).to be_nil
    end
  end

  context 'on Linux' do
    let(:dsc_binary) { '/opt/dsc/dsc' }

    before :each do
      allow(Facter).to receive(:value).and_call_original
      allow(Facter).to receive(:value).with(:kernel).and_return('Linux')
    end

    it 'returns structured fact when DSC binary exists' do
      allow(File).to receive(:exist?).with(dsc_binary).and_return(true)
      allow(Facter::Core::Execution).to receive(:execute).with("#{dsc_binary} --version 2>&1", on_fail: nil).and_return('dsc 3.0.1')

      result = Facter.value(:dscv3_info)
      expect(result).to be_a(Hash)
      expect(result['install_path']).to eq('/opt/dsc')
      expect(result['version']).to eq('3.0.1')
    end

    it 'returns nil when DSC binary does not exist' do
      allow(File).to receive(:exist?).with(dsc_binary).and_return(false)

      expect(Facter.value(:dscv3_info)).to be_nil
    end
  end

  context 'on macOS' do
    let(:dsc_binary) { '/usr/local/dsc/dsc' }

    before :each do
      allow(Facter).to receive(:value).and_call_original
      allow(Facter).to receive(:value).with(:kernel).and_return('Darwin')
    end

    it 'returns structured fact when DSC binary exists' do
      allow(File).to receive(:exist?).with(dsc_binary).and_return(true)
      allow(Facter::Core::Execution).to receive(:execute).with("#{dsc_binary} --version 2>&1", on_fail: nil).and_return('dsc 3.1.2')

      result = Facter.value(:dscv3_info)
      expect(result).to be_a(Hash)
      expect(result['install_path']).to eq('/usr/local/dsc')
      expect(result['version']).to eq('3.1.2')
    end

    it 'returns nil when DSC binary does not exist' do
      allow(File).to receive(:exist?).with(dsc_binary).and_return(false)

      expect(Facter.value(:dscv3_info)).to be_nil
    end
  end

  context 'version parsing' do
    let(:dsc_binary) { '/opt/dsc/dsc' }

    before :each do
      allow(Facter).to receive(:value).and_call_original
      allow(Facter).to receive(:value).with(:kernel).and_return('Linux')
      allow(File).to receive(:exist?).with(dsc_binary).and_return(true)
    end

    it 'parses version from "dsc X.Y.Z" format' do
      allow(Facter::Core::Execution).to receive(:execute).with("#{dsc_binary} --version 2>&1", on_fail: nil).and_return('dsc 3.0.1')

      result = Facter.value(:dscv3_info)
      expect(result['version']).to eq('3.0.1')
    end

    it 'parses version from just "X.Y.Z" format' do
      allow(Facter::Core::Execution).to receive(:execute).with("#{dsc_binary} --version 2>&1", on_fail: nil).and_return('3.0.1')

      result = Facter.value(:dscv3_info)
      expect(result['version']).to eq('3.0.1')
    end

    it 'returns unknown when version output has no semantic version' do
      allow(Facter::Core::Execution).to receive(:execute).with("#{dsc_binary} --version 2>&1", on_fail: nil).and_return('unknown format')

      result = Facter.value(:dscv3_info)
      expect(result['version']).to eq('unknown')
    end
  end
end
