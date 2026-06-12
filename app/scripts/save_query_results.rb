require "json"
require_relative "questions"

OUTFILE = "query_parser_results_2.json"

results =
  QUERY_PARSER_QUESTIONS.map do |question|
    puts "Parsing: #{question}"

    sleep(2.1)

    {
      question: question,
      result: Tasks::QueryParser.parse(question)
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
puts "Saved #{results.size} query parser results."
puts path
