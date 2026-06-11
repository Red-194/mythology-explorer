module Llm
  class Client
    PROVIDER = Providers::Groq

    class << self
      def chat(messages:, model:, temperature: 0.1)
        PROVIDER.chat(
          messages: messages,
          model: model,
          temperature: temperature
        )
      end
    end
  end
end
