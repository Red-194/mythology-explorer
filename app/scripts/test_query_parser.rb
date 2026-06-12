require_relative "questions"

# change this to questions_1 or questions_2 depending on which you want to test

QUERY_PARSER_QUESTIONS.each_with_index do |question, index|
  puts
  puts "=" * 100
  puts "#{index + 1}. #{question}"
  puts "-" * 100

  begin
    result = Tasks::QueryParser.parse(question)

    pp result
  rescue => e
    if e.message.include?("rate_limit")
      sleep 5
      retry
    end
  end
end
