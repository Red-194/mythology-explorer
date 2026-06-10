require "json"
require "set"

# INPUT_FILE  = "data/glossary_analysis/v3/master_facts_normalized.json"
# OUTPUT_FILE = "data/glossary_analysis/v3/graph.json"

# INPUT_FILE  = "data/glossary_analysis/v4/master_facts_resolved.json"
# OUTPUT_FILE = "data/glossary_analysis/v4/resolved_graph.json"

# INPUT_FILE  = "data/glossary_analysis/v4/master_facts_resolved_2.json"
# OUTPUT_FILE = "data/glossary_analysis/v4/resolved_graph_2.json"

INPUT_FILE  = "data/glossary_analysis/v5/master_facts_final.json"
OUTPUT_FILE = "data/glossary_analysis/v5/resolved_graph_final.json"

facts = JSON.parse(File.read(INPUT_FILE))

nodes = {}
edges = []

facts.each do |fact|
  subject = fact["subject"]
  object = fact["object"]

  nodes[subject] ||= {
    "id" => subject,
    "type" => "entity"
  }

  nodes[object] ||= {
    "id" => object,
    "type" => "entity"
  }

  edges << {
    "id" => fact["id"],
    "source" => subject,
    "target" => object,
    "predicate" => fact["predicate"],
    "evidence" => fact["evidence"],
    "source_term" => fact["source_term"],
    "pages" => fact["pages"]
  }
end

graph = {
  "metadata" => {
    "node_count" => nodes.length,
    "edge_count" => edges.length
  },
  "nodes" => nodes.values,
  "edges" => edges
}

File.write(
  OUTPUT_FILE,
  JSON.pretty_generate(graph)
)

puts "Nodes: #{nodes.length}"
puts "Edges: #{edges.length}"
puts "Written to #{OUTPUT_FILE}"
