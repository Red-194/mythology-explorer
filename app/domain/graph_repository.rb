# app/domain/graph_repository.rb

require "json"

class GraphRepository
  class << self
    def query(entity:, predicate:)
      direct_matches(entity, predicate) +
        inverse_matches(entity, predicate)
    end

    private

    def direct_matches(entity, predicate)
      edges
        .select do |edge|
          edge["source"] == entity &&
          edge["predicate"] == predicate
        end
        .map { |edge| edge["target"] }
    end

    def inverse_matches(entity, predicate)
      inverse = Ontology.inverse(predicate)

      return [] if inverse.nil?

      edges
        .select do |edge|
          edge["target"] == entity &&
          edge["predicate"] == inverse
        end
        .map { |edge| edge["source"] }
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

    def edges
      graph["edges"]
    end
  end
end
