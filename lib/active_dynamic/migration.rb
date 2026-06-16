class CreateActiveDynamicAttributesTable < ActiveRecord::Migration[4.2]
  def change
    create_table :active_dynamic_attributes do |t|
      t.integer :customizable_id, null: false
      t.string :customizable_type, limit: 50

      t.string :name
      t.string :display_name, null: false
      t.integer :datatype
      t.text :value
      t.text :encrypted_value
      t.boolean :required, null: false, default: false

      t.timestamps
    end

    add_index :active_dynamic_attributes, :customizable_id
    add_index :active_dynamic_attributes, :customizable_type
    add_index :active_dynamic_attributes,
              [:customizable_id, :customizable_type, :name],
              unique: true,
              name: 'index_active_dynamic_attributes_on_owner_and_name'
  end
end
