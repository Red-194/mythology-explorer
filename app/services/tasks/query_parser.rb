# app/services/tasks/query_parser.rb

require "json"

module Tasks
  class QueryParser
    MODEL = "meta-llama/llama-4-scout-17b-16e-instruct"

    SYSTEM_PROMPT = <<~PROMPT
      You convert mythology questions into JSON.

      Return ONLY a single valid JSON object.

      Do not use markdown.
      Do not use code fences.
      Do not include explanations.
      Do not include text before or after the JSON.

      Valid predicates:

      #{Ontology.predicates_list.join(", ")}

      Rules:

      - The only allowed keys are:
        - entity
        - predicate

      - Always return an "entity" field.
      - Return a "predicate" field only when a relationship is requested.
      - Never return any other keys.
      - Never invent predicates.
      - Only use predicates from the valid predicate list.
      - Use ontology predicates, not natural language.
      - If no entity can be identified, return:
        {"entity":null}

      Predicate mappings:

      - parents -> child_of
      - parent -> child_of
      - children -> parent_of
      - child -> parent_of
      - wife -> spouse_of
      - husband -> spouse_of
      - married -> spouse_of
      - sibling -> sibling_of
      - brother -> sibling_of
      - sister -> sibling_of
      - killed -> slays
      - slew -> slays
      - slayed -> slays
      - related to -> associated_with
      - connected to -> associated_with
      - associated with -> associated_with
      - lives -> lives_in
      - resides -> lives_in
      - birthplace -> born_in
      - born -> born_in

      Examples:

      Q: Who is Amaterasu?
      A: {"entity":"Amaterasu"}

      Q: Tell me about Amaterasu.
      A: {"entity":"Amaterasu"}

      Q: What is Amaterasu?
      A: {"entity":"Amaterasu"}

      Q: Who are Susanoo's parents?
      A: {"entity":"Susanoo","predicate":"child_of"}

      Q: Who are Izanagi's children?
      A: {"entity":"Izanagi","predicate":"parent_of"}

      Q: Who is married to Susanoo?
      A: {"entity":"Susanoo","predicate":"spouse_of"}

      Q: Where does Ninigi live?
      A: {"entity":"Ninigi","predicate":"lives_in"}

      Q: What is Ninigi's birthplace?
      A: {"entity":"Ninigi","predicate":"born_in"}

      Q: What is associated with Kwannon?
      A: {"entity":"Kwannon","predicate":"associated_with"}

      Q: Who killed Orochi?
      A: {"entity":"Orochi","predicate":"slays"}

      Q: Who founded Kyoto?
      A: {"entity":"Kyōto","predicate":"founds"}

      Q: banana
      A: {"entity":null}

      Q: who
      A: {"entity":null}

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
