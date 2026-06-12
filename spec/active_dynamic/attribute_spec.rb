require 'spec_helper'
require_relative '../support/profile'

RSpec.describe ActiveDynamic::Attribute do
  subject(:attribute) { described_class.new(attributes) }

  describe '#initialize' do
    context 'when given a value and the encryption flag' do
      let(:attributes) { { value: 'secret', encrypt_value: true } }

      it 'routes the value to the encrypted column, like any other write' do
        expect(attribute.encrypted_value).to eq('secret')
        expect(attribute.read_attribute(:value)).to be_nil
      end
    end

    context 'when given a value without the flag' do
      let(:attributes) { { value: 'plain' } }

      it 'routes the value to the plaintext column' do
        expect(attribute.read_attribute(:value)).to eq('plain')
        expect(attribute.encrypted_value).to be_nil
      end
    end

    context 'when no value is given' do
      let(:attributes) { { encrypted_value: 'secret' } }

      it 'does not clear an explicitly assigned encrypted value' do
        expect(attribute.encrypted_value).to eq('secret')
      end
    end
  end

  describe '#assign_attributes' do
    context 'when the row is already encrypted' do
      let(:attributes) { { encrypted_value: 'secret' } }

      it 'routes a value: through the encrypted column' do
        attribute.assign_attributes(value: 'updated')

        expect(attribute.encrypted_value).to eq('updated')
        expect(attribute.read_attribute(:value)).to be_nil
      end
    end

    context 'when value: comes before encrypt_value: in the hash' do
      let(:attributes) { {} }

      it 'still routes to the encrypted column — routing cannot depend on key order' do
        attribute.assign_attributes(value: 'secret', encrypt_value: true)

        expect(attribute.encrypted_value).to eq('secret')
        expect(attribute.read_attribute(:value)).to be_nil
      end
    end

    context 'when explicitly clearing an encrypted row with value: nil' do
      let(:attributes) { { encrypted_value: 'secret' } }

      it 'clears the encrypted column, honoring normal assignment semantics' do
        attribute.assign_attributes(value: nil)

        expect(attribute.value).to be_nil
        expect(attribute.encrypted_value).to be_nil
      end
    end

    context 'when explicitly clearing a plaintext row with value: nil' do
      let(:attributes) { { value: 'plain' } }

      it 'clears the plaintext column' do
        attribute.assign_attributes(value: nil)

        expect(attribute.value).to be_nil
        expect(attribute.read_attribute(:value)).to be_nil
      end
    end
  end

  describe '#encrypt_value' do
    context 'when the transient flag is set' do
      let(:attributes) { { encrypt_value: true } }

      it { expect(attribute.encrypt_value).to be(true) }
    end

    context 'when the row already stores an encrypted value' do
      let(:attributes) { { encrypted_value: 'secret' } }

      it 'is true even without the flag, so a row never downgrades to plaintext' do
        expect(attribute.encrypt_value).to be(true)
      end
    end

    context 'when the flag is not set and there is no encrypted value' do
      let(:attributes) { { value: 'plain' } }

      it 'is falsey' do
        expect(attribute.encrypt_value).to be_falsey
      end
    end
  end

  describe '#value' do
    # Write the columns directly: #value= and #assign_attributes route a given
    # value, and these contexts simulate rows as loaded from the database
    # (which bypass both — AR instantiates them via init_with).
    subject(:attribute) do
      described_class.new.tap { |record| attributes.each { |column, column_value| record[column] = column_value } }
    end

    context 'when an encrypted value is present' do
      let(:attributes) { { value: 'plain', encrypted_value: 'secret' } }

      it 'returns the encrypted value' do
        expect(attribute.value).to eq('secret')
      end
    end

    context 'when the encrypted value is nil' do
      let(:attributes) { { value: 'plain', encrypted_value: nil } }

      it 'falls back to the plaintext column' do
        expect(attribute.value).to eq('plain')
      end
    end

    context 'when the encrypted value is an empty string' do
      let(:attributes) { { value: 'plain', encrypted_value: '' } }

      it 'returns the empty string — it is a real stored value, not a missing one' do
        expect(attribute.value).to eq('')
      end
    end
  end

  describe '#value=' do
    context 'when flagged for encryption and given an empty string' do
      let(:attributes) { { encrypt_value: true } }

      it 'round-trips the empty string like the plaintext path does' do
        attribute.value = ''

        expect(attribute.value).to eq('')
      end
    end

    context 'when flagged for encryption' do
      let(:attributes) { { value: 'plain', encrypt_value: true } }

      it 'routes to the encrypted column and clears the plaintext column' do
        attribute.value = 'secret'

        expect(attribute.encrypted_value).to eq('secret')
        expect(attribute.read_attribute(:value)).to be_nil
      end
    end

    context 'when not flagged' do
      let(:attributes) { { encrypted_value: nil } }

      it 'routes to the plaintext column and clears the encrypted column' do
        attribute.value = 'plain'

        expect(attribute.read_attribute(:value)).to eq('plain')
        expect(attribute.encrypted_value).to be_nil
      end
    end

    context 'when the row is already encrypted and the flag is turned off' do
      let(:attributes) { { encrypted_value: 'secret' } }

      it 'keeps writing to the encrypted column' do
        attribute.encrypt_value = false
        attribute.value = 'updated secret'

        expect(attribute.encrypted_value).to eq('updated secret')
        expect(attribute.read_attribute(:value)).to be_nil
      end
    end

    context 'when explicitly clearing an encrypted row with nil' do
      let(:attributes) { { encrypted_value: 'secret' } }

      it 'clears the encrypted column' do
        attribute.value = nil

        expect(attribute.value).to be_nil
        expect(attribute.encrypted_value).to be_nil
      end
    end
  end

  describe '#encrypted_value' do
    subject(:attribute) do
      described_class.create!(
        customizable: Profile.create!(first_name: 'Dwight'),
        name: 'ssn',
        display_name: 'SSN',
        datatype: ActiveDynamic::DataType::Text,
        encrypted_value: '123-45-6789'
      )
    end

    it 'stores ciphertext at rest, not plaintext' do
      sql = ActiveRecord::Base.sanitize_sql(
        ['SELECT encrypted_value FROM active_dynamic_attributes WHERE id = ?', attribute.id]
      )
      raw = ActiveRecord::Base.connection.select_value(sql)

      expect(raw).to be_present
      expect(raw).not_to include('123-45-6789')
      expect(JSON.parse(raw).keys).to eq(['p', 'h']) # Active Record Encryption payload envelope
    end

    it 'decrypts transparently on read' do
      expect(attribute.reload.value).to eq('123-45-6789')
    end
  end

  describe 'persisting through value: with the encryption flag' do
    subject(:attribute) do
      described_class.create!(
        customizable: Profile.create!(first_name: 'Dwight'),
        name: 'ssn',
        display_name: 'SSN',
        datatype: ActiveDynamic::DataType::Text,
        value: '123-45-6789',
        encrypt_value: true
      )
    end

    it 'stores the submitted value encrypted, not in the plaintext column' do
      raw = ActiveRecord::Base.connection.select_one(
        'SELECT value, encrypted_value FROM active_dynamic_attributes WHERE id = :id', nil, [attribute.id]
      )

      expect(raw['value']).to be_nil
      expect(raw['encrypted_value']).to be_present
      expect(raw['encrypted_value']).not_to include('123-45-6789')
      expect(attribute.reload.value).to eq('123-45-6789')
    end
  end
end
