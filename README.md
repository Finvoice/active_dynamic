# ActiveDynamic

ActiveDynamic allows you to dynamically add properties to your ActiveRecord
models and work with them as regular properties.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'active_dynamic'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install active_dynamic

## Usage

To make this gem work, first you need to add `has_dynamic_attributes` to the model that needs to have dynamic 
attributes. For example, if you have `Profile` model:
 
```ruby
class Profile < ActiveRecord::Base
  has_dynamic_attributes
  
  # ...
end  
```

After that you need to set a class that will resolve definitions of the dynamic attributes to be created on `Profile` model:

```ruby
# lib/initializers/dynamic_attribute.rb

ActiveDynamic.configure do |config|
  config.provider_class = ProfileAttributeProvider
end

class ProfileAttributeProvider

  # Constructor will receive an instance to which dynamic attributes are added
  def initialize(model)
    @model = model
  end
  
  # This method has to return array of dynamic field definitions.
  # You can get it from the configuration file, DB, etc., depending on your app logic
  def call
    [
      # attribute definition has to specify attribute display name
      ActiveDynamic::AttributeDefinition.new('biography'),
      
      # Optionally you can provide datatype, system name, and default value.
      # If system name is not specified, it will be generated automatically from display name
      ActiveDynamic::AttributeDefinition.new('age', datatype: ActiveDynamic::DataType::Integer, default_value: 18),

      # Sensitive attributes can be stored with Active Record Encryption.
      ActiveDynamic::AttributeDefinition.new('ssn', encrypt_value: true)
    ]
  end
  
end

```

### Encrypted dynamic values

Pass `encrypt_value: true` to `ActiveDynamic::AttributeDefinition` for sensitive
fields:

```ruby
ActiveDynamic::AttributeDefinition.new(
  'ssn',
  datatype: ActiveDynamic::DataType::Text,
  encrypt_value: true
)
```

Encrypted fields are stored in `active_dynamic_attributes.encrypted_value`
using Active Record Encryption. The plaintext `value` column is cleared for
those rows, and callers continue to read and write the field through the normal
dynamic accessor:

```ruby
profile.ssn = '123-45-6789'
profile.save!
profile.reload.ssn # => '123-45-6789'
```

Existing plaintext rows still read normally. If a field is later marked with
`encrypt_value: true`, the next write to that field stores the value encrypted
and clears the plaintext column. Rows already stored encrypted keep using the
encrypted column even if a later definition passes `encrypt_value: false`, so
values do not silently downgrade back to plaintext. To move a row back to
plaintext storage, clear its `encrypted_value` column first. Once
`encrypted_value` is `NULL` and the field definition no longer passes
`encrypt_value: true`, future writes use the plaintext `value` column.

To resolve dynamic attribute definitions for more than one model:

```ruby
class Profile < ActiveRecord::Base
  has_dynamic_attributes
  
  # ...
end  
 
class Document < ActiveRecord::Base
  has_dynamic_attributes
  
  # ...
end  
 
class ProfileAttributeProvider
 
  def initialize(model)
    @model = model   
  end
  
  def call
    case @model
      when Profile
        [
          # attribute definitions for Profile model
        ]
      when Document
        [
          # attribute definitions for Document model
        ]
      else
        []
    end
  end
  
end
```

## How ActiveDynamic resolves dynamic attributes

When you work with unsaved models, ActiveDynamic will use `provider_class` to resolve a list 
of dynamic attributes, and it will store them alongside the model when the model is saved. 
So next time when you load that model from DB, ActiveDynamic won't look into `provider_class` 
and it will load only the dynamic attributes that were created when the model was saved for 
the first time.

If you want dynamic attributes to be resolved from `provider_class` for persisted models as well,
you can use `resolve_persisted` configuration option:

```ruby
# lib/initializers/dynamic_attribute.rb

ActiveDynamic.configure do |config|
  # ... 
  
  # you can set it to Bool value to apply the behavior to all models
  config.resolve_persisted = true
  
  # or you can set it to a Proc to configure the behavior on per-class basis
  config.resolve_persisted = Proc.new { |model| model.is_a?(Profile) ? true  : false }
end
```

## Querying

**This is still work in progress, so think twice before using it in production 🙂**

ActiveDynamic provides `where_dynamic` class method, that you can use to search by dynamic fields. For example, if you have a `Profile` model with `age` attribute, you can use it like this:

```ruby
  Profile.where_dynamic(age: 21)
```

At the moment, only hash arguments are supported.

`where_dynamic` queries the plaintext `value` column and is intended only for
non-encrypted dynamic attributes. Attributes defined with `encrypt_value: true`
are stored in `encrypted_value` and are not queryable with `where_dynamic`.
Avoid using encrypted dynamic attributes as filters.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
