require "json"
require "set"

path = "data/glossary_analysis/v3"
FACTS_FILE = "#{path}/master_facts_normalized.json"

facts = JSON.parse(File.read(FACTS_FILE))

entities = Set.new

facts.each do |fact|
  entities << fact["subject"]
  entities << fact["object"]
end

entities = entities.to_a.sort

def normalize(name)
  name
    .downcase
    .gsub(/\([^)]*\)/, "")
    .gsub(/[^\p{Alnum}\s-]/, " ")
    .gsub(/\s+/, " ")
    .strip
end

#
# Build neighborhood context
#
entity_facts = Hash.new { |h, k| h[k] = [] }

facts.each do |fact|
  entity_facts[fact["subject"]] << {
    role: "subject",
    predicate: fact["predicate"],
    other: fact["object"]
  }

  entity_facts[fact["object"]] << {
    role: "object",
    predicate: fact["predicate"],
    other: fact["subject"]
  }
end

groups = Hash.new { |h, k| h[k] = [] }

entities.each do |entity|
  groups[normalize(entity)] << entity
end

candidates = []

#
# Same normalized name
#
groups.each_value do |members|
  next if members.size < 2

  candidates << {
    reason: "same_normalized_name",
    entities: members
  }
end

#
# Name containment
#
entities.combination(2) do |a, b|
  na = normalize(a)
  nb = normalize(b)

  shorter, longer =
    na.length < nb.length ? [ na, nb ] : [ nb, na ]

  next if shorter.length < 5

  if longer.include?(shorter)
    candidates << {
      reason: "name_contains_other",
      entities: [ a, b ]
    }
  end
end

#
# Deduplicate
#
seen = Set.new

candidates.select! do |candidate|
  key = candidate[:entities].sort.join("|||")

  next false if seen.include?(key)

  seen << key
  true
end

#
# Enrich with graph context
#
candidates.each do |candidate|
  candidate[:context] = {}

  candidate[:entities].each do |entity|
    candidate[:context][entity] =
      entity_facts[entity]
        .first(10)
  end
end

output = {
  total_entities: entities.size,
  candidate_groups: candidates
}

File.write(
  "entity_resolution_candidates.json",
  JSON.pretty_generate(output)
)

puts "Entities: #{entities.size}"
puts "Candidate groups: #{candidates.size}"
puts "Written: entity_resolution_candidates.json"
