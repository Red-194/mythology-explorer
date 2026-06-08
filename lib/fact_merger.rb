require "json"

path = "data/glossary_analysis/v2"

FILES = [
  "facts-A_E.json",
  "facts-F_J.json",
  "facts-K_O.json",
  "facts-P_T.json",
  "facts-U_Z.json"
]

all_facts = FILES.flat_map do |file|
  JSON.parse(File.read("#{path}/#{file}"))
end

merged = {}

all_facts.each do |fact|
  key = [
    fact["subject"]&.strip,
    fact["predicate"]&.strip,
    fact["object"]&.strip
  ]

  if merged.key?(key)
    merged[key]["pages"] |= fact["pages"] || []

    evidence = Array(merged[key]["evidence"])
    evidence << fact["evidence"]
    merged[key]["evidence"] = evidence.uniq

    source_terms = Array(merged[key]["source_term"])
    source_terms << fact["source_term"]
    merged[key]["source_term"] = source_terms.uniq
  else
    merged[key] = fact.dup
    merged[key]["evidence"] = [ fact["evidence"] ].compact
    merged[key]["source_term"] = [ fact["source_term"] ].compact
  end
end

File.write(
  "master_facts.json",
  JSON.pretty_generate(merged.values)
)

puts "Original facts: #{all_facts.size}"
puts "Unique facts: #{merged.size}"
puts "Duplicates removed: #{all_facts.size - merged.size}"
