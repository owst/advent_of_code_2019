def input(str = nil)
  str ||= $stdin.read

  str.chars.map(&:to_i)
end

def apply_pattern(cells, pattern)
  lengthened_pattern = pattern.cycle.take(cells.length + 1).drop(1)
  cells.zip(lengthened_pattern).map { |l, r| l * r }.sum.abs % 10
end

def calculate_pattern(position)
  base_pattern = [0, 1, 0, -1]

  base_pattern.flat_map { |d| [d] * position }
end

def step(cells)
  (1..cells.length).map { |pos| apply_pattern(cells, calculate_pattern(pos)) }
end

puts 100.times.reduce(input) { |cells| step(cells) }.take(8).join
