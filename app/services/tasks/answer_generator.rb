# app/services/tasks/answer_generator.rb

module Tasks
  class AnswerGenerator
    MODEL = "meta-llama/llama-4-scout-17b-16e-instruct"

    SYSTEM_PROMPT = <<~PROMPT
      You answer mythology questions.

      Use ONLY the supplied graph results.

      Never invent facts.
      Never use outside knowledge.

      If the graph contains no answer,
      clearly say that the information
      was not found in the mythology
      knowledge graph.

      Keep answers concise.
    PROMPT

    class << self
      def generate(question)
        query = QueryParser.parse(question)

        result =
          if query["predicate"]
            GraphRepository.query(
              type: query["type"],
              entity: query["entity"],
              predicate: query["predicate"]
            )
          else
            GraphRepository.entity(
              query["entity"]
            )
          end

        return not_found(question) if blank_result?(result)

        Llm::Client.chat(
          messages: [
            {
              role: "system",
              content: SYSTEM_PROMPT
            },
            {
              role: "user",
              content: build_context(
                question: question,
                query: query,
                result: result
              )
            }
          ],
          model: MODEL,
          temperature: 0
        )
      end

      private

      def build_context(
        question:,
        query:,
        result:
      )
        <<~TEXT
          Question:

          #{question}

          Parsed Query:

          #{query.to_json}

          Graph Result:

          #{result.to_json}
        TEXT
      end

      def blank_result?(result)
        result.nil? ||
          (result.respond_to?(:empty?) &&
           result.empty?)
      end

      def not_found(question)
        "I couldn't find information about that in the mythology knowledge graph."
      end
    end
  end
end
