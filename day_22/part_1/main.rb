def parse(str = nil)
  str ||= ARGF.read

  str.split("\n").map do |line|
    case line
    when /new stack/
      then [:new_stack]
    when /increment (\d+)/
      then [:increment, Regexp.last_match[1].to_i]
    when /cut (-?\d+)/
      then [:cut, Regexp.last_match[1].to_i]
    else
      raise "Urk: #{line}"
    end
  end
end

def apply(steps, size)
  steps.reduce((0...size).to_a) do |state, (step, arg)|
    case step
    when :new_stack
      state.reverse
    when :increment
      is = [0]

      is << (is.last + arg) % size until is.size == size

      state.values_at(*is.zip(0...size).sort_by(&:first).map { |_, i| i })
    when :cut
      n = arg.negative? ? size + arg : arg

      state.drop(n) + state.take(n)
    end
  end
end

# def test_case(size, input)
#   *input_lines, expected_line = input.split("\n")
#   expected = expected_line.gsub(/Result: /, '').split(" ").map(&:to_i)

#   p apply(parse(input_lines.join("\n")), size) == expected
# end

# test_case(10, <<~STR)
#   deal with increment 7
#   deal into new stack
#   deal into new stack
#   Result: 0 3 6 9 2 5 8 1 4 7
# STR

# test_case(10, <<~STR)
#   cut 6
#   deal with increment 7
#   deal into new stack
#   Result: 3 0 7 4 1 8 5 2 9 6
# STR

# test_case(10, <<~STR)
#   deal with increment 7
#   deal with increment 9
#   cut -2
#   Result: 6 3 0 7 4 1 8 5 2 9
# STR

# test_case(10, <<~STR)
#   deal into new stack
#   cut -2
#   deal with increment 7
#   cut 8
#   cut -4
#   deal with increment 7
#   cut 3
#   deal with increment 9
#   deal with increment 3
#   cut -1
#   Result: 9 2 5 8 1 4 7 0 3 6
# STR

apply(parse, 10007).each_with_index do |c, i|
  if c == 2019
    puts i
    break
  end
end
