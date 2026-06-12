# app/services/tasks/query_parser.rb

require "json"

module Tasks
  class QueryParser
    MODEL = "meta-llama/llama-4-scout-17b-16e-instruct"
    SYSTEM_PROMPT = <<~PROMPT
      You convert mythology questions into JSON.

      Return ONLY a single valid JSON object.

      Valid query types:

      - entity_lookup
      - relationship_lookup
      - reverse_relationship_lookup

      Ontology:

      #{Ontology.prompt_text}

      Rules:

      - Allowed keys:
        - type
        - entity
        - predicate

      - Always return:
        - type
        - entity

      - Return predicate only for relationship queries.

      - The predicate MUST be one of the ontology predicates.
      - Never invent predicates.
      - Never invent entities.

      - Copy entity names exactly from the question.
      - Do not substitute similar entities.
      - Do not normalize entity names.
      - Alias resolution happens later.

      - entity_lookup:
        Information about an entity.

      - relationship_lookup:
        Entity is the source of the relationship.

      - reverse_relationship_lookup:
        Entity is the target of the relationship.

      - entity_lookup must never contain a predicate.

      - If a predicate is present:
        type must be:
          relationship_lookup
          or
          reverse_relationship_lookup

      - Questions asking:
        - where is
        - where was
        - where does
        - where can I find

        are relationship queries, not entity lookups.

      - If no entity can be identified:
        {"type":"entity_lookup","entity":null}
      Examples:

      Q: Who is Amaterasu?
      A: {"type":"entity_lookup","entity":"Amaterasu"}

      Q: Tell me about Amaterasu.
      A: {"type":"entity_lookup","entity":"Amaterasu"}

      Q: Who are Susanoo's parents?
      A: {"type":"relationship_lookup","entity":"Susanoo","predicate":"child_of"}

      Q: Who are Izanagi's children?
      A: {"type":"reverse_relationship_lookup","entity":"Izanagi","predicate":"child_of"}

      Q: Who is married to Susanoo?
      A: {"type":"relationship_lookup","entity":"Susanoo","predicate":"spouse_of"}

      Q: Who founded Kamakura?
      A: {"type":"reverse_relationship_lookup","entity":"Kamakura","predicate":"founds"}

      Q: Who serves Amaterasu?
      A: {"type":"reverse_relationship_lookup","entity":"Amaterasu","predicate":"servant_of"}

      Q: Who is Kaguya's suitor?
      A: {"type":"reverse_relationship_lookup","entity":"Kaguya","predicate":"suitor_of"}

      Q: Who created Shingon-shū?
      A: {"type":"reverse_relationship_lookup","entity":"Shingon-shū","predicate":"founds"}

      Q: Who created Hō-jō-ki?
      A: {"type":"reverse_relationship_lookup","entity":"Hō-jō-ki","predicate":"creates"}

      Q: banana
      A: {"type":"entity_lookup","entity":null}

      Never explain why an entity cannot be identified.

      Never return sentences such as:
      "Since no entity was found..."
      "Unable to determine..."
      "The question is ambiguous..."

      Return JSON only.

      Your entire response must be parseable by JSON.parse().
    PROMPT

    class << self
      def parse(question)
        response = Llm::Client.chat(
          messages: [
            {
              role: "system",
              content: SYSTEM_PROMPT
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
