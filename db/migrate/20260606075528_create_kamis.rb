class CreateKamis < ActiveRecord::Migration[7.2]
  def change
    create_table :kamis do |t|
      t.string :name, null: false
      t.string :canonical_name
      t.string :translation
      t.integer :generation
    end
    add_index :kamis, :canonical_name, unique: true
  end
end
