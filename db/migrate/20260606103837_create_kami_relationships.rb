class CreateKamiRelationships < ActiveRecord::Migration[7.2]
  def change
    create_table :kami_relationships do |t|
      t.references :source_kami, null: false, foreign_key: { to_table: :kamis }
      t.references :target_kami, null: false, foreign_key: { to_table: :kamis }
      t.integer :relationship_type, null: false
    end

    add_index(
      :kami_relationships,
      [ :source_kami_id, :target_kami_id, :relationship_type ],
      unique: true
    )
  end
end
