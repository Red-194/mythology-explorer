# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

require "json"

path = "db/data"

# Inserting the kami data
Kami.delete_all
kamis = JSON.parse(
  File.read(Rails.root.join("#{path}/kamis.json"))
)
Kami.insert_all!(kamis)


# Inserting the kami relationship data
KamiRelationship.delete_all
kami_relationships = JSON.parse(
  File.read(Rails.root.join("#{path}/kami_relationships.json"))
)

kami_relationships.each do |relationship|
  source = Kami.find_by!(
    name: relationship["source"]
  )
  target = Kami.find_by!(
    name: relationship["target"]
  )

  KamiRelationship.create!(
    source_kami: source,
    target_kami: target,
    relationship_type: relationship["relationship_type"]
  )
end
