require 'set'

def split_parse(input)
  input.split(',').map do |str|
    dir = str[0]

    raise "Bad dir: #{dir}" unless dir =~ /[UDLR]/

    str[0] = ''

    [dir, str.to_i]
  end
end

def covered_cells(wire)
  start = [0, 0]

  wire.reduce([start, [start]]) do |((x, y), cells), (dir, move)|
    new_cells = (1..move).map do |i|
      case dir
      when 'U' then [x, y + i]
      when 'D' then [x, y - i]
      when 'R' then [x + i, y]
      when 'L' then [x - i, y]
      end
    end

    [new_cells.last, cells + new_cells]
  end[1]
end

def cross_points(covered_a, covered_b)
  (covered_a & covered_b) - [[0, 0]]
end

def min_combined_distance_crossing(covered_cells_a, covered_cells_b, crossings)
  crossings.map { |c| covered_cells_a.find_index(c) + covered_cells_b.find_index(c) }.min
end

# solve('R75,D30,R83,U83,L12,D49,R71,U7,L72', 'U62,R66,U55,R34,D71,R55,D58,R83') = 610
# solve('R98,U47,R26,D63,R33,U87,L62,D20,R33,U53,R51', 'U98,R91,D20,R16,D67,R40,U7,R15,U6,R7') = 410
def solve(input_a, input_b)
  covered_cells_a = covered_cells(split_parse(input_a))
  covered_cells_b = covered_cells(split_parse(input_b))

  min_combined_distance_crossing(
    covered_cells_a,
    covered_cells_b,
    cross_points(covered_cells_a, covered_cells_b)
  )
end

p solve($stdin.readline, $stdin.readline)
