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

        key = cache_key(question)
        cached = read_cache(key)

        if cached
          @total_usage["tokens_saved"] = cached["tokens_used"]
          @total_usage["from_cache"] = true
          return cached["answer"]
        end

        tokens_before = total_tokens_spent

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

        answer =
          if blank_result?(result)
            not_found(question)
          else
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

        accumulate_usage

        tokens_used = total_tokens_spent - tokens_before
        write_cache(key, answer, tokens_used)

        answer
      end

      def cache_stats
        {
          hits: cache_hits,
          misses: cache_misses,
          size: cache.size
        }
      end

      def clear_cache
        @cache = {}
        @cache_hits = 0
        @cache_misses = 0
        @tokens_spent_counter = 0
      end

      private

      def cache
        @cache ||= {}
      end

      def cache_hits
        @cache_hits = 0 unless defined?(@cache_hits)
        @cache_hits
      end

      def cache_misses
        @cache_misses = 0 unless defined?(@cache_misses)
        @cache_misses
      end

      def cache_key(question)
        question.downcase.strip.gsub(/\?$/, "").gsub(/\s+/, " ")
      end

      def write_cache(key, answer, tokens)
        cache[key] = {
          "answer" => answer,
          "tokens_used" => tokens
        }
      end

      def read_cache(key)
        if cache.key?(key)
          @cache_hits = 0 unless defined?(@cache_hits)
          @cache_hits += 1
          cache[key]
        else
          @cache_misses = 0 unless defined?(@cache_misses)
          @cache_misses += 1
          nil
        end
      end

      def total_tokens_spent
        @tokens_spent_counter ||= 0
        @tokens_spent_counter
      end

      def track_classification(query)
        if query["entity"].nil? && query["type"] == "entity_lookup"
          # Garbage input — no LLM call made
          @total_usage["tokens_saved"] = 250
        elsif query["type"] == "entity_lookup" && query["predicate"].nil?
          # Entity lookup — no LLM call made
          @total_usage["tokens_saved"] = 250
        elsif query["predicate"]
          # Relationship query — used local parser, only 1 LLM call for answer
          @total_usage["tokens_saved"] = 700
        end
      end

      def accumulate_usage
        usage = Providers::Groq.drain_usage
        return unless usage

        @total_usage["prompt_tokens"] += usage["prompt_tokens"]
        @total_usage["completion_tokens"] += usage["completion_tokens"]
        @total_usage["total_tokens"] += usage["total_tokens"]

        @tokens_spent_counter += usage["total_tokens"]
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
