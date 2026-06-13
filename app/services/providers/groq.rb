require "http"
require "json"

module Providers
  class Groq
    BASE_URL = "https://api.groq.com/openai/v1/chat/completions"

    class << self
      attr_reader :last_usage

      def chat(messages:, model:, temperature: 0.1)
        response = HTTP
          .headers(
            "Authorization" => "Bearer #{ENV.fetch('GROQ_API_KEY')}",
            "Content-Type" => "application/json"
          )
          .post(
            BASE_URL,
            json: {
              model: model,
              temperature: temperature,
              messages: messages
            }
          )

        body = JSON.parse(response.body.to_s)

        unless response.status.success?
          raise StandardError, body.inspect
        end

        @last_usage = body["usage"]
        body.dig(
          "choices",
          0,
          "message",
          "content"
        )&.strip
      end
    end
  end
end
