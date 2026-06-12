require "json"
require_relative "questions"

OUTFILE = "answer_generator_results_2.json"

results =
  ANSWER_GENERATOR_QUESTIONS.map do |question|
    puts "Answering: #{question}"

    {
      question: question,
      result: Tasks::AnswerGenerator.generate(question)
    }
  end

path = Rails.root.join(
  "app",
  "scripts",
  "query_results",
  OUTFILE
)

File.write(
  path,
  JSON.pretty_generate(results)
)

puts
puts "Saved #{results.size} answer generator results."
puts path
