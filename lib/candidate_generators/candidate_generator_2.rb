require "json"
require "set"

path = "data/glossary_analysis/v4"

FACTS_FILE = "#{path}/master_facts_resolved_1.json"
OUTPUT_FILE = "#{path}/entity_resolution_candidates_2.json"

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

def canonical_tokens(name)
  name
    .downcase
    .gsub(/[^\p{Alnum}\s]/, " ")
    .split
    .reject { |w| %w[the of and in on at to for from].include?(w) }
    .sort
    .join(" ")
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

candidates = []

#
# Rule 1: same_normalized_name
#
groups = Hash.new { |h, k| h[k] = [] }

entities.each do |entity|
  groups[normalize(entity)] << entity
end

groups.each_value do |members|
  next if members.size < 2

  candidates << {
    reason: "same_normalized_name",
    entities: members
  }
end

#
# Rule 2: name_contains_other
# Match whole words, not arbitrary substrings
#
entities.combination(2) do |a, b|
  na = normalize(a)
  nb = normalize(b)

  shorter, longer =
    na.length < nb.length ? [ na, nb ] : [ nb, na ]

  next if shorter.length < 5

  shorter_tokens = shorter.split
  longer_tokens  = longer.split

  next unless (shorter_tokens - longer_tokens).empty?

  candidates << {
    reason: "name_contains_other",
    entities: [ a, b ]
  }
end

#
# Rule 3: same_tokens_reordered
#
token_groups = Hash.new { |h, k| h[k] = [] }

entities.each do |entity|
  token_groups[canonical_tokens(entity)] << entity
end

token_groups.each_value do |members|
  next if members.size < 2

  candidates << {
    reason: "same_tokens_reordered",
    entities: members
  }
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
  OUTPUT_FILE,
  JSON.pretty_generate(output)
)

puts "Entities: #{entities.size}"
puts "Candidate groups: #{candidates.size}"
puts "Written: #{OUTPUT_FILE}"
