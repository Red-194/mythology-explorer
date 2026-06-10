require "json"

FACTS_FILE = "data/glossary_analysis/v4/master_facts_resolved_2.json"
PASS1_FILE = "data/glossary_analysis/v3/entity_resolution_results_1.json"
PASS2_FILE = "data/glossary_analysis/v4/entity_resolution_results_2.json"

FINAL_FACTS_FILE = "data/glossary_analysis/v5/master_facts_final.json"
ALIASES_FILE = "data/glossary_analysis/v5/entity_aliases.json"
CROSS_REFERENCES_FILE = "data/glossary_analysis/v5/cross_references.json"

facts = JSON.parse(File.read(FACTS_FILE))
pass1 = JSON.parse(File.read(PASS1_FILE))
pass2 = JSON.parse(File.read(PASS2_FILE))

results = []
results.concat(pass1["results"])
results.concat(pass2)

#
# Build alias registry
#
aliases = Hash.new { |h, k| h[k] = [] }

results.each do |entry|
  next unless entry["classification"] == "SAME_ENTITY"

  canonical = entry["canonical"]

  next if canonical.nil? || canonical.strip.empty?

  entry["entities"].each do |entity|
    next if entity == canonical

    aliases[canonical] << entity
  end
end

aliases.each_value(&:uniq!)
aliases = aliases.sort.to_h

#
# Extract cross references
#
cross_references = []

facts.each do |fact|
  next unless fact["predicate"] == "cross_reference"

  cross_references << {
    "source" => fact["subject"],
    "target" => fact["object"],
    "evidence" => fact["evidence"],
    "source_term" => fact["source_term"],
    "pages" => fact["pages"]
  }
end

#
# Remove alias and cross-reference relationships from KG
#
original_count = facts.size

clean_facts = facts.reject do |fact|
  %w[
    alias_of
    cross_reference
  ].include?(fact["predicate"])
end

removed_edges = original_count - clean_facts.size

#
# Write outputs
#
File.write(
  FINAL_FACTS_FILE,
  JSON.pretty_generate(clean_facts)
)

File.write(
  ALIASES_FILE,
  JSON.pretty_generate(aliases)
)

File.write(
  CROSS_REFERENCES_FILE,
  JSON.pretty_generate(cross_references)
)

alias_count =
  aliases.values.sum(&:size)

puts "Original facts:          #{original_count}"
puts "Removed metadata edges:  #{removed_edges}"
puts "Final KG facts:          #{clean_facts.size}"
puts
puts "Canonical entities:      #{aliases.size}"
puts "Alias mappings:          #{alias_count}"
puts
puts "Cross references:        #{cross_references.size}"
puts
puts "Written: #{FINAL_FACTS_FILE}"
puts "Written: #{ALIASES_FILE}"
puts "Written: #{CROSS_REFERENCES_FILE}"
