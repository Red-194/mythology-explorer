# app/services/tasks/query_parser.rb

require "json"

module Tasks
  class QueryParser
    MODEL = "meta-llama/llama-4-scout-17b-16e-instruct"

    BASE_PROMPT = <<~PROMPT
      You convert mythology questions into JSON.
      Return ONLY a single valid JSON object.

      Valid query types:
      - entity_lookup
      - relationship_lookup
      - reverse_relationship_lookup

      Ontology:

      ONTOLOGY_PLACEHOLDER

      Rules:
      - Allowed keys: type, entity, predicate
      - Always return: type, entity
      - Return predicate only for relationship queries.
      - The predicate MUST be one of the ontology predicates.
      - Never invent predicates or entities.
      - Copy entity names exactly from the question.
      - Do not substitute similar entities.
      - entity_lookup must never contain a predicate.
      - Questions with "where is/where was/where does/where can I find" are relationship queries, not entity lookups.
      - If no entity can be identified: {"type":"entity_lookup","entity":null}

      Examples:
      Q: Who is Amaterasu?
      A: {"type":"entity_lookup","entity":"Amaterasu"}

      Q: Who are Susanoo's parents?
      A: {"type":"relationship_lookup","entity":"Susanoo","predicate":"child_of"}

      Q: Who are Izanagi's children?
      A: {"type":"reverse_relationship_lookup","entity":"Izanagi","predicate":"child_of"}

      Q: Who founded Kamakura?
      A: {"type":"reverse_relationship_lookup","entity":"Kamakura","predicate":"founds"}

      Q: banana
      A: {"type":"entity_lookup","entity":null}

      Never explain why an entity cannot be identified.
      Never return sentences.
      Return JSON only.
      Your entire response must be parseable by JSON.parse().
    PROMPT

    class << self
      def parse(question)
        classified = QueryClassifier.classify(question)

        if classified && classified[:skip_llm]
          query = {
            "type" => classified[:type],
            "entity" => classified[:entity]
          }
          query["predicate"] = classified[:candidate_predicates].first if classified[:candidate_predicates].any?
          return apply_alias_resolution(query)
        end

        system_prompt = build_system_prompt(classified)

        response = Llm::Client.chat(
          messages: [
            {
              role: "system",
              content: system_prompt
            },
            {
              role: "user",
              content: question
            }
          ],
          model: MODEL,
          temperature: 0
        )

        query =
          begin
            JSON.parse(response)
          rescue JSON::ParserError
            Rails.logger.error(
              "QueryParser invalid JSON: #{response}"
            )
            raise
          end

        apply_alias_resolution(query)
      end

      private

      def build_system_prompt(classified)
        if classified && classified[:candidate_predicates].any?
          ontology_section = Ontology.prompt_text_for(
            classified[:candidate_predicates]
          )
        else
          ontology_section = Ontology.prompt_text
        end

        BASE_PROMPT.sub("ONTOLOGY_PLACEHOLDER", ontology_section)
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
