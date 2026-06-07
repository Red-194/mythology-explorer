# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_06_06_103837) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "kami_relationships", force: :cascade do |t|
    t.bigint "source_kami_id", null: false
    t.bigint "target_kami_id", null: false
    t.integer "relationship_type", null: false
    t.index ["source_kami_id", "target_kami_id", "relationship_type"], name: "idx_on_source_kami_id_target_kami_id_relationship_t_3a3272a063", unique: true
    t.index ["source_kami_id"], name: "index_kami_relationships_on_source_kami_id"
    t.index ["target_kami_id"], name: "index_kami_relationships_on_target_kami_id"
  end

  create_table "kamis", force: :cascade do |t|
    t.string "name", null: false
    t.string "canonical_name"
    t.string "translation"
    t.integer "generation"
    t.index ["canonical_name"], name: "index_kamis_on_canonical_name", unique: true
  end

  add_foreign_key "kami_relationships", "kamis", column: "source_kami_id"
  add_foreign_key "kami_relationships", "kamis", column: "target_kami_id"
end
