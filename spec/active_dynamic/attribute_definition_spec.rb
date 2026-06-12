require 'spec_helper'

RSpec.describe ActiveDynamic::AttributeDefinition do
  subject(:definition) { described_class.new('SSN', params) }

  describe '#encrypt_value' do
    context 'when the option is not given' do
      let(:params) { { datatype: ActiveDynamic::DataType::Text } }

      it { expect(definition.encrypt_value).to be(false) }
    end

    context 'when the option is given' do
      let(:params) { { datatype: ActiveDynamic::DataType::Text, encrypt_value: true } }

      it { expect(definition.encrypt_value).to be(true) }
    end
  end

  describe '#initialize' do
    context 'with options it does not know about' do
      let(:params) { { datatype: ActiveDynamic::DataType::Text, encrypt_value: true, tooltip: 'Nine digits' } }

      it 'still assigns them as readers' do
        expect(definition.tooltip).to eq('Nine digits')
      end
    end

    context 'when system_name is not given' do
      let(:params) { { datatype: ActiveDynamic::DataType::Text } }

      it { expect(definition.name).to eq('ssn') }
      it { expect(definition.display_name).to eq('SSN') }
    end

    context 'when system_name is given' do
      let(:params) { { datatype: ActiveDynamic::DataType::Text, system_name: 'social_security_number' } }

      it { expect(definition.name).to eq('social_security_number') }
    end

    context 'when default_value is given' do
      let(:params) { { datatype: ActiveDynamic::DataType::Text, default_value: 'N/A' } }

      it { expect(definition.value).to eq('N/A') }
    end

    context 'when required is not given' do
      let(:params) { { datatype: ActiveDynamic::DataType::Text } }

      it { expect(definition.required).to be(false) }
      it { expect(definition.value).to be_nil }
    end

    context 'when required is given' do
      let(:params) { { datatype: ActiveDynamic::DataType::Text, required: true } }

      it { expect(definition.required).to be(true) }
    end
  end

  describe '#required?' do
    context 'when required is false' do
      let(:params) { { datatype: ActiveDynamic::DataType::Text } }

      it { expect(definition.required?).to be(false) }
    end

    context 'when required is true' do
      let(:params) { { datatype: ActiveDynamic::DataType::Text, required: true } }

      it { expect(definition.required?).to be(true) }
    end
  end
end
