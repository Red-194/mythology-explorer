# app/services/tasks/query_parser.rb
#
# Fully local query parser — no LLM calls.
# Uses QueryClassifier for intent + predicate selection,
# AliasResolver for entity name resolution.

require "json"

module Tasks
  class QueryParser
    class << self
      def parse(question)
        classified = QueryClassifier.classify(question)

        query = if classified
          build_query(classified)
        else
          {
            "type" => "entity_lookup",
            "entity" => nil
          }
        end

        apply_alias_resolution(query)
      end

      private

      def build_query(classified)
        query = {
          "type" => classified[:type],
          "entity" => classified[:entity]
        }

        # For relationship queries, try each candidate predicate
        # and pick the first that actually matches in the graph
        if classified[:candidate_predicates].any?
          query["predicate"] = find_working_predicate(
            classified[:type],
            classified[:entity],
            classified[:candidate_predicates]
          )
        end

        query
      end

      def find_working_predicate(type, entity, candidates)
        # Try each candidate against the graph; return first match.
        # If none match, return the first candidate anyway — the
        # graph may simply not have the data.
        candidates.each do |predicate|
          results = GraphRepository.query(
            type: type,
            entity: entity,
            predicate: predicate
          )
          return predicate if results.any?
        end
        candidates.first
      end

      def apply_alias_resolution(query)
        if query["entity"]
          query["entity"] =
            AliasResolver.resolve(query["entity"]) ||
            query["entity"]
        end
        query
      end
    end
  end
end
