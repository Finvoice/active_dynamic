require 'spec_helper'
require_relative 'support/profile'

# End-to-end behavior of the gem driven through a host model (`Profile`) and its provider.
# The persisted/encryption path lives in `has_dynamic_attributes_spec`; this spec covers the
# public surface: version, the provider-backed `dynamic_attributes`, and save/load/validate.
RSpec.describe ActiveDynamic do
  let(:profile) { Profile.new(first_name: 'Dwight') }

  before do
    ActiveDynamic.configure do |c|
      c.provider_class = ProfileAttributeProvider
      c.resolve_persisted = false
    end
  end

  it 'exposes a version number' do
    expect(ActiveDynamic::VERSION).not_to be_nil
  end

  describe '#dynamic_attributes' do
    subject(:dynamic_attributes) { profile.dynamic_attributes }

    it do
      expect(dynamic_attributes).to be_an(Array)
      expect(dynamic_attributes.map(&:name)).to eq(['life_story', 'age', 'home_town'])
      expect(dynamic_attributes.map(&:display_name)).to eq(
        ['Life Story', 'Age', 'Please, tell us what is your home town']
      )
    end

    it 'exposes accessors and the loaded-state predicate on the host' do
      expect(profile).to respond_to(:life_story, :dynamic_attributes_loaded?)
    end
  end

  describe '#save' do
    it 'persists a value set through the generated accessor' do
      profile.life_story = 'Beet farmer / Paper Salesman'

      expect(profile.save).to be_truthy
      expect(profile.life_story).to eq('Beet farmer / Paper Salesman')
    end

    it 'persists values assigned through .new' do
      profile = Profile.new(first_name: 'Michael', life_story: 'Basketball machine')

      expect(profile.save).to be_truthy
      expect(profile.life_story).to eq('Basketball machine')
    end

    it 'accepts integer-typed values' do
      profile.age = 21

      expect(profile.save).to be_truthy
    end

    context 'when a required dynamic attribute is missing' do
      it 'does not persist' do
        profile.life_story = nil

        expect(profile.save).to be_falsey
        expect(profile).not_to be_persisted
      end
    end

    context 'when the save fails' do
      let(:profile) { Profile.new } # first_name is required, so the record is invalid

      it 'keeps assigned dynamic values in memory' do
        profile.life_story = 'Beet farmer / Paper Salesman'
        profile.save

        expect(profile).not_to be_persisted
        expect(profile.life_story).to eq('Beet farmer / Paper Salesman')
      end
    end
  end

  describe '#home_town=' do
    it 'allows clearing a value back to nil' do
      profile.life_story = 'Beet farmer / Paper Salesman'
      profile.home_town = 'Scranton'
      profile.save!
      profile.home_town = nil

      expect(profile.home_town).to be_nil
    end
  end

  describe '.find' do
    it 'reloads persisted dynamic values' do
      profile.life_story = 'Beet farmer / Paper Salesman'
      profile.save!

      expect(Profile.find(profile.id).life_story).to eq('Beet farmer / Paper Salesman')
    end
  end

  describe '.where_dynamic' do
    it 'finds records by a dynamic attribute value' do
      [18, 21].each { |age| Profile.create!(first_name: 'Jon', age:) }

      expect(Profile.where_dynamic(age: 18).count).to eq(1)
    end
  end

  context 'when resolve_persisted is enabled' do
    before do
      ActiveDynamic.configure do |c|
        c.provider_class = ProfileAttributeProvider
        c.resolve_persisted = true
      end
    end

    it 'updates values on a persisted record' do
      profile = Profile.create!(first_name: 'Michael', life_story: 'Basketball machine')

      expect(profile.update(life_story: 'Regional manager')).to be_truthy
    end

    describe '#should_resolve_persisted?' do
      subject(:should_resolve_persisted?) { Profile.new.send(:should_resolve_persisted?) }

      it 'returns the boolean config value' do
        expect(should_resolve_persisted?).to be(true)
      end

      context 'when configured with a proc' do
        before { ActiveDynamic.configure { |c| c.resolve_persisted = proc { |_model| true } } }

        it 'evaluates the proc against the model' do
          expect(should_resolve_persisted?).to be(true)
        end
      end
    end
  end
end
