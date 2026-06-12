# app/domain/graph_repository.rb

require "json"

class GraphRepository
  class << self
    def entity(name)
      nodes.find do |node|
        node["id"] == name
      end
    end

    def query(type:, entity:, predicate:)
      case type
      when "relationship_lookup"
        outgoing_matches(
          entity,
          predicate
        )

      when "reverse_relationship_lookup"
        incoming_matches(
          entity,
          predicate
        )

      else
        []
      end
    end

    private

    def outgoing_matches(entity, predicate)
      edges
        .select do |edge|
          edge["source"] == entity &&
          edge["predicate"] == predicate
        end
        .map do |edge|
          edge["target"]
        end
    end

    def incoming_matches(entity, predicate)
      edges
        .select do |edge|
          edge["target"] == entity &&
          edge["predicate"] == predicate
        end
        .map do |edge|
          edge["source"]
        end
    end

    def graph
      @graph ||= JSON.parse(
        File.read(
          Rails.root.join(
            "knowledge",
            "graph.json"
          )
        )
      )
    end

    def nodes
      graph["nodes"]
    end

    def edges
      graph["edges"]
    end
  end
end
