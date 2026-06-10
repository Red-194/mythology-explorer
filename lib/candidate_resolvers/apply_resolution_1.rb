require "json"
require "set"

path = "data/glossary_analysis"

FACTS_FILE = "#{path}/v3/master_facts_normalized.json"
RESOLUTION_FILE = "#{path}/v3/patches/candidate_resolver.json"
OUTPUT_FILE = "#{path}/v4/master_facts_resolved.json"

facts = JSON.parse(File.read(FACTS_FILE))
resolution_data = JSON.parse(File.read(RESOLUTION_FILE))

results =
  if resolution_data.is_a?(Hash) && resolution_data["results"]
    resolution_data["results"]
  else
    resolution_data
  end

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
puts "Original facts:      #{facts.size}"
puts "Resolved facts:      #{resolved_facts.size}"
puts "Deduplicated facts:  #{deduplicated.size}"
puts "Written: #{OUTPUT_FILE}"
