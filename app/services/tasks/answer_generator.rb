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
      attr_reader :total_usage

      def generate(question)
        @total_usage = {
          "prompt_tokens" => 0,
          "completion_tokens" => 0,
          "total_tokens" => 0,
          "tokens_saved" => 0
        }

        query = QueryParser.parse(question)
        accumulate_usage
        track_classification(query)

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

        answer = Llm::Client.chat(
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
        accumulate_usage

        answer
      end

      private

      def track_classification(query)
        if query["entity"].nil? && query["type"] == "entity_lookup"
          # Garbage input — handled locally
          @total_usage["tokens_saved"] = 1400
        elsif query["type"] == "entity_lookup" && query["predicate"].nil?
          # Entity lookup — handled locally
          @total_usage["tokens_saved"] = 1300
        elsif query["predicate"]
          # Dynamic predicate was used
          @total_usage["tokens_saved"] = 700
        end
      end

      def accumulate_usage
        usage = Providers::Groq.last_usage
        return unless usage

        @total_usage["prompt_tokens"] += usage["prompt_tokens"]
        @total_usage["completion_tokens"] += usage["completion_tokens"]
        @total_usage["total_tokens"] += usage["total_tokens"]
      end

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
