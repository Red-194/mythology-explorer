require "json"
require "set"

FACTS_FILE = "data/glossary_analysis/v4/master_facts_resolved_1.json"
RESOLUTION_FILE = "data/glossary_analysis/v4/entity_resolution_results_2.json"
OUTPUT_FILE = "data/glossary_analysis/v4/master_facts_resolved_2.json"

facts = JSON.parse(File.read(FACTS_FILE))
results = JSON.parse(File.read(RESOLUTION_FILE))

merge_map = {}

results.each do |entry|
  next unless entry["classification"] == "SAME_ENTITY"
  canonical = entry["canonical"]
  next if canonical.nil? || canonical.strip.empty?
  entry["entities"].each do |entity|
    next if entity == canonical
    merge_map[entity] = canonical
  end
end

puts "Merge mappings: #{merge_map.size}"

merge_map.sort.each do |from, to|
  puts "  #{from} -> #{to}"
end

resolved_facts = facts.map do |fact|
  updated = fact.dup

  updated["subject"] =
    merge_map.fetch(updated["subject"], updated["subject"])

  updated["object"] =
    merge_map.fetch(updated["object"], updated["object"])

  updated
end

seen = Set.new
deduplicated = []

resolved_facts.each do |fact|
  key = [
    fact["subject"],
    fact["predicate"],
    fact["object"]
  ]

  next if seen.include?(key)

  seen.add(key)
  deduplicated << fact
end

File.write(
  OUTPUT_FILE,
  JSON.pretty_generate(deduplicated)
)

puts
puts "Original facts:     #{facts.size}"
puts "Resolved facts:     #{resolved_facts.size}"
puts "Deduplicated facts: #{deduplicated.size}"
puts "Written: #{OUTPUT_FILE}"
