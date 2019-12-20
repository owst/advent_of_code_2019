require 'awesome_print'

def parse(input = nil)
  input ||= $stdin.read
  input.split("\n").map do |line|
    left, right = line.split(" => ")

    parse_side = ->(side) { n, l = side.split(" "); [n.to_i, l] }

    [left.split(",").map { |l| parse_side.call(l) }, parse_side.call(right)]
  end
end

res = parse(<<~MSG)
  10 ORE => 10 A
  1 ORE => 1 B
  7 A, 1 B => 1 C
  7 A, 1 C => 1 D
  7 A, 1 D => 1 E
  7 A, 1 E => 1 FUEL
MSG

# A => [10, [10, ORE]]
# B => [1, [1, ORE]]
# C => [1, [7, A], [1, B]]
# D => [1, [7, A], [1, C]]
# E => [1, [7, A], [1, D]]
# FUEL => [1, [7, A], [1, E]]

lookup = res.map do |inputs, (output_count, output_name)|
  [output_name, [output_count, inputs]]
end.to_h

def go(lookup, name, repeat = 1)
  count, inputs = lookup.fetch(name)

  inputs.map do |input_count, input_name|
    if input_name == "ORE"
      [[]]
    else
      go(lookup, input_name, input_count).map do |x|
        x * input_count
      end
    end
  end
end

p go(lookup, "FUEL")
