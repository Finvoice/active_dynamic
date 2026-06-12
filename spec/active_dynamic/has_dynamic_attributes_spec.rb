require 'spec_helper'
require_relative '../support/profile'

# The provider as it looked before the SSN field was flagged for encryption — used to
# materialize historical plaintext rows for the flag-enabling scenarios.
class PlaintextSsnProfileAttributeProvider < ProfileAttributeProvider
  def call
    super.map do |definition|
      next definition unless definition.name == 'ssn'

      ActiveDynamic::AttributeDefinition.new('SSN', datatype: ActiveDynamic::DataType::Text)
    end
  end
end

RSpec.describe ActiveDynamic::HasDynamicAttributes do
  let(:profile) { Profile.create!(first_name: 'Dwight', life_story: 'Beet farmer') }

  before do
    ActiveDynamic.configure do |c|
      c.provider_class = ProfileAttributeProvider
      c.resolve_persisted = true
    end
  end

  describe '.where_dynamic' do
    it 'returns records matching the given dynamic attribute value' do
      profile
      other = Profile.create!(first_name: 'Jim', life_story: 'Sales')

      expect(Profile.where_dynamic(life_story: 'Beet farmer')).to eq([profile])
      expect(Profile.where_dynamic(life_story: 'Sales')).to eq([other])
    end

    it { expect(Profile.where_dynamic(life_story: 'Astronaut')).to be_empty }
  end

  describe '#save_dynamic_attributes' do
    context 'when the field is flagged for encryption' do
      let(:profile) { Profile.create!(first_name: 'Dwight', life_story: 'Beet farmer', ssn: '123-45-6789') }

      it 'stores the value in the encrypted column and leaves the plaintext column empty' do
        row = profile.active_dynamic_attributes.find_by(name: 'ssn')

        expect(row.read_attribute(:value)).to be_nil
        expect(row.read_attribute_before_type_cast(:encrypted_value)).not_to include('123-45-6789')
      end

      it { expect(Profile.find(profile.id).ssn).to eq('123-45-6789') }

      it 'updates the existing row instead of creating a duplicate' do
        Profile.find(profile.id).update!(ssn: '999-99-9999')
        Profile.find(profile.id).update!(ssn: '888-88-8888')

        expect(profile.active_dynamic_attributes.where(name: 'ssn').count).to eq(1)
        expect(Profile.find(profile.id).ssn).to eq('888-88-8888')
      end
    end

    context 'when the field is not flagged' do
      it do
        row = profile.active_dynamic_attributes.find_by(name: 'life_story')

        expect(row.read_attribute(:value)).to eq('Beet farmer')
        expect(row.read_attribute(:encrypted_value)).to be_nil
      end
    end

    it 'creates one row per assigned field and skips fields without a value' do
      expect(profile.active_dynamic_attributes.pluck(:name)).to eq(['life_story'])
    end

    it 'strips surrounding whitespace from the value' do
      profile.update!(life_story: '  Beet farmer  ')

      expect(profile.active_dynamic_attributes.find_by(name: 'life_story').value).to eq('Beet farmer')
    end
  end

  describe '#dynamic_attributes' do
    subject(:dynamic_attributes) { Profile.find(profile.id).dynamic_attributes }

    it 'does not write to the database on read' do
      profile

      expect { dynamic_attributes }.not_to change(ActiveDynamic::Attribute, :count)
    end

    it { expect(dynamic_attributes).to be_an(Array) }

    it 'returns provider-only fields as in-memory records' do
      home_town = dynamic_attributes.find { |attribute| attribute.name == 'home_town' }

      expect(home_town).to be_new_record
    end

    it 'prefers the persisted row over the provider definition for the same name' do
      stories = dynamic_attributes.select { |attribute| attribute.name == 'life_story' }

      expect(stories.map(&:value)).to eq(['Beet farmer'])
    end

    context 'when the record is new' do
      subject(:dynamic_attributes) { Profile.new(first_name: 'Jim').dynamic_attributes }

      it { expect(dynamic_attributes).to all(be_a(ActiveDynamic::AttributeDefinition)) }
    end

    context 'when resolve_persisted is false' do
      before do
        profile # persist before flipping the flag so create! runs with a working config
        ActiveDynamic.configure { |c| c.resolve_persisted = false }
      end

      it { expect(dynamic_attributes.map(&:name)).to eq(['life_story']) }
    end
  end

  describe '#respond_to?' do
    it { expect(profile).to respond_to(:life_story) }
    it { expect(profile).not_to respond_to(:nonexistent_field) }
  end

  describe 'required field validation' do
    it 'is invalid when a required field is blank' do
      profile.life_story = ''

      expect(profile).not_to be_valid
    end
  end

  context 'when a field is flagged for encryption after plaintext rows exist' do
    let(:profile) { Profile.create!(first_name: 'Dwight', life_story: 'Beet farmer', ssn: '111-11-1111') }

    before do
      # Persist the profile while the field is unflagged, then flip to the flagged
      # provider — the same shape as deploying a `MetaField#encrypt_value` change.
      ActiveDynamic.configure { |c| c.provider_class = PlaintextSsnProfileAttributeProvider }
      profile
      ActiveDynamic.configure do |c|
        c.provider_class = ProfileAttributeProvider
        c.resolve_persisted = true
      end
    end

    it { expect(profile.active_dynamic_attributes.find_by(name: 'ssn').read_attribute(:value)).to eq('111-11-1111') }

    it { expect(Profile.find(profile.id).ssn).to eq('111-11-1111') }

    it 'stamps the definition flag onto the persisted row' do
      ssn = Profile.find(profile.id).dynamic_attributes.find { |attribute| attribute.name == 'ssn' }

      expect(ssn).to be_persisted
      expect(ssn.encrypt_value).to be(true)
    end

    it 're-routes the value to the encrypted column on the next update' do
      Profile.find(profile.id).update!(ssn: '222-22-2222')

      row = profile.reload.active_dynamic_attributes.find_by(name: 'ssn')
      expect(row.read_attribute(:value)).to be_nil
      expect(row.value).to eq('222-22-2222')
    end
  end

  describe '#initialize_dup' do
    before { profile.life_story } # force-load the dynamic accessors on the original

    it 'lets a duped record resolve its own dynamic accessors' do
      expect { profile.dup.life_story }.not_to raise_error
    end

    it 'does not share loaded state with the original' do
      copy = profile.dup
      copy.life_story = 'Assistant to the regional manager'

      expect(profile.life_story).to eq('Beet farmer')
    end
  end
end
