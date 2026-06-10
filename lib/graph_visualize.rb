# lib/visualize_graph.rb

require "json"
require "graphviz"

# INPUT_FILE = "data/glossary_analysis/v3/graph.json"
# OUTPUT_FILE = "data/glossary_analysis/v3/mythology_graph.png"

# INPUT_FILE = "data/glossary_analysis/v4/resolved_graph.json"
# OUTPUT_FILE = "data/glossary_analysis/v4/resolved_mythology_graph.png"

# INPUT_FILE = "data/glossary_analysis/v4/resolved_graph_2.json"
# OUTPUT_FILE = "data/glossary_analysis/v4/resolved_mythology_graph_2.png"

INPUT_FILE = "data/glossary_analysis/v5/resolved_graph_final.json"
OUTPUT_FILE = "data/glossary_analysis/v5/resolved_mythology_graph_final.png"

graph_data = JSON.parse(File.read(INPUT_FILE))

g = GraphViz.new(
  :G,
  type: :graph,
  overlap: false,
  splines: true,
  layout: "sfdp"
)

nodes = {}

graph_data["nodes"].each do |node|
  nodes[node["id"]] = g.add_nodes(node["id"])
end

graph_data["edges"].each do |edge|
  source = nodes[edge["source"]]
  target = nodes[edge["target"]]

  next unless source && target

  g.add_edges(source, target)
end

g.output(png: OUTPUT_FILE)

puts "Nodes: #{graph_data["nodes"].size}"
puts "Edges: #{graph_data["edges"].size}"
puts "Written to #{OUTPUT_FILE}"
