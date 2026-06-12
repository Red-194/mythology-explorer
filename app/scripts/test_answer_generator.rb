require_relative "questions"

ANSWER_GENERATOR_QUESTIONS.each_with_index do |question, index|
  puts
  puts "=" * 100
  puts "#{index + 1}. #{question}"
  puts "-" * 100

  begin
    answer =
      Tasks::AnswerGenerator.generate(
        question
      )

    puts answer
  rescue => e
    puts "ERROR: #{e.class}"
    puts e.message
  end

  # Prevent Groq TPM/RPM limits
  sleep 4
end

puts
puts "=" * 100
puts "Finished #{ANSWER_GENERATOR_QUESTIONS.size} questions."
puts "=" * 100
