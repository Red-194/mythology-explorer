require "json"

GRAPH_FILE = "data/glossary_analysis/v5/resolved_graph_final.json"
OUTPUT_FILE = "data/glossary_analysis/v5/ontology.json"

graph = JSON.parse(File.read(GRAPH_FILE))

predicate_counts = Hash.new(0)

graph["edges"].each do |edge|
  predicate_counts[edge["predicate"]] += 1
end

ontology = {}

predicate_counts.sort.each do |predicate, count|
  ontology[predicate] = {
    "description" => "",
    "count" => count,
    "inverse" => nil,
    "symmetric" => false
  }
end

# Known relationships
if ontology["parent_of"] && ontology["child_of"]
  ontology["parent_of"]["inverse"] = "child_of"
  ontology["child_of"]["inverse"] = "parent_of"
end

if ontology["spouse_of"]
  ontology["spouse_of"]["inverse"] = "spouse_of"
  ontology["spouse_of"]["symmetric"] = true
end

File.write(
  OUTPUT_FILE,
  JSON.pretty_generate(ontology)
)

puts "Predicates: #{ontology.length}"
puts

ontology.each do |predicate, data|
  puts "#{predicate.ljust(20)} #{data['count']}"
end

puts
puts "Written to #{OUTPUT_FILE}"
