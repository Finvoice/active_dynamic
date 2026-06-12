require 'spec_helper'
require_relative 'support/profile'

RSpec.describe ActiveDynamic do
  let(:profile) { Profile.new }

  # Reset the process-global ActiveDynamic configuration before every example so a
  # `resolve_persisted = true` example cannot leak into the next one.
  before do
    ActiveDynamic.configure do |c|
      c.provider_class = ProfileAttributeProvider
      c.resolve_persisted = false
    end
  end

  it 'initializes with a dynamic attribute' do
    profile = Profile.new(first_name: 'Dwight', life_story: 'Beet farmer / Paper Salesman')
    profile.save!

    expect(profile).to be_persisted
  end

  it 'has a version number' do
    expect(ActiveDynamic::VERSION).not_to be_nil
  end

  it 'injects dynamic attributes' do
    expect(profile.dynamic_attributes).to be_a(Array)
  end

  it 'responds to dynamic_attributes_loaded?' do
    expect(profile).to respond_to(:dynamic_attributes_loaded?)
  end

  it 'exposes accessors from the attribute provider' do
    expect(profile).to respond_to(:life_story)
  end

  it 'sets the attribute names' do
    expect(profile.dynamic_attributes.map(&:name)).to eq(['life_story', 'age', 'home_town', 'ssn'])
  end

  it 'sets the display name' do
    expect(profile.dynamic_attributes.map(&:display_name).first).to eq('Life Story')
  end

  it 'does not reset the field on a failed save' do
    profile.life_story = 'Beet farmer / Paper Salesman'
    profile.save

    expect(profile).not_to be_persisted
    expect(profile.life_story).to eq('Beet farmer / Paper Salesman')
  end

  it 'persists a dynamic attribute' do
    profile.first_name = 'Dwight'
    profile.life_story = 'Beet farmer / Paper Salesman'
    profile.save

    expect(profile).to be_persisted
    expect(profile.life_story).not_to be_empty
  end

  it 'persists when initialized with attributes' do
    profile = Profile.new(first_name: 'Michael', life_story: 'Basketball machine')
    profile.save

    expect(profile).to be_persisted
    expect(profile.life_story).not_to be_empty
  end

  it 'loads dynamic attributes on find' do
    profile.first_name = 'Dwight'
    profile.life_story = 'Beet farmer / Paper Salesman'
    profile.save

    loaded_profile = Profile.find(profile.id)
    expect(loaded_profile.life_story).to eq('Beet farmer / Paper Salesman')
  end

  it 'validates a required attribute' do
    profile.life_story = nil
    profile.save

    expect(profile).not_to be_persisted
  end

  it 'supports integer values' do
    profile.age = 21
    profile.first_name = 'Joe'

    expect(profile.save).to be_truthy
  end

  it 'allows nil values' do
    profile.home_town = 'Scranton'
    profile.first_name = 'Dwight'
    profile.life_story = 'Beet farmer / Paper Salesman'
    profile.save
    profile.home_town = nil

    expect(profile.home_town).to be_nil
  end

  it 'looks up records with where_dynamic and a hash' do
    [18, 21].each { |age| Profile.new(first_name: 'Jon', age:).save! }

    expect(Profile.where_dynamic(age: 18).first).to be_truthy
  end

  context 'when resolve_persisted is enabled' do
    before do
      ActiveDynamic.configure do |config|
        config.provider_class = ProfileAttributeProvider
        config.resolve_persisted = true
      end
    end

    it 'updates values on a persisted record' do
      profile = Profile.new(first_name: 'Michael', life_story: 'Basketball machine')
      profile.save

      expect(profile.update(life_story: 'Regional manager')).to be_truthy
    end

    it 'handles a boolean resolve_persisted value' do
      expect(Profile.new.send(:should_resolve_persisted?)).to be_truthy
    end

    it 'handles a proc resolve_persisted value' do
      ActiveDynamic.configure { |config| config.resolve_persisted = proc { |_model| true } }

      expect(Profile.new.send(:should_resolve_persisted?)).to be_truthy
    end
  end
end
