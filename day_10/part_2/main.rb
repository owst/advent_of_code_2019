require 'awesome_print'

Vector = Struct.new(:x, :y) do
  def to_s
    "<#{x}, #{y}>"
  end

  def delta(other)
    self.class.new(x - other.x, y - other.y)
  end

  # Turn [4, 2] into [2, 1], and [9, 3] into [3, 1] - this means that we treat all vectors in the
  # same line as equal.
  def normalise
    gcd = x.gcd(y)
    gcd = 1 if gcd.zero?

    self.class.new(x / gcd, y / gcd)
  end

  def magnitude
    Math.sqrt(x ** 2 + y ** 2)
  end

  def dot(other)
    x * other.x + y * other.y
  end

  def angle_from_north
    # Inspiration from https://stackoverflow.com/a/16716872
    res = Math.atan2(x, -y)

    res.negative? ? res + 2 * Math::PI : res
  end
end

class Asteroid
  attr_reader :char, :pos, :delta

  def initialize(char, pos, delta = nil)
    @char = char
    @pos = pos
    @delta = delta
  end

  def to_s
    "A<#{char}, #{pos}, #{delta}>"
  end

  alias inspect to_s

  def with_delta(other)
    self.class.new(char, pos, pos.delta(other.pos))
  end
end

def find_asteroids(input)
  input.split("\n").each_with_index.flat_map do |row, y|
    row.chars.each_with_index.map do |char, x|
      char != '.' ? [Asteroid.new(char, Vector.new(x, y))] : []
    end
  end.flatten(1)
end

def deltas(asteroids)
  asteroids.map do |base_asteroid|
    [
      base_asteroid,
      (asteroids - [base_asteroid]).map { |asteroid| asteroid.with_delta(base_asteroid) }
    ]
  end.to_h
end

input = $stdin.read
asteroids = find_asteroids(input)

visibles = deltas(asteroids).transform_values do |asteroid_deltas|
  asteroid_deltas.group_by { |a| a.delta.normalise }
end

best_coord, best_visibles = visibles.max_by { |_, v| v.size }

p best_coord
puts best_visibles.size

def order_by_angle_from_north(best_visibles)
  best_visibles.sort_by { |k, _| k.angle_from_north }.map { |_k, v| v }.map { |coords|
    coords.sort_by { |d| d.delta.magnitude }
  }
end

def enumerate(ordered)
  return to_enum(__method__, ordered) unless block_given?

  loop do
    break if ordered.empty?

    x,*xs = ordered.shift

    yield x

    ordered.push(xs) unless xs.empty?
  end
end

def extract(str)
  find_asteroids(str).select { |a| a.char =~ /[0-9]/ }.sort_by { |a| a.char.to_i }.map(&:pos)
end

# input = <<~STR
# .#....#####...#..
# ##...##.#####..##
# ##...#...#.#####.
# ..#.....X...###..
# ..#.#.....#....##
# STR

#first_nine = extract(<<~STR)
#  .#....###24...#..
#  ##...##.13#67..9#
#  ##...#...5.8####.
#  ..#.....X...###..
#  ..#.#.....#....##
#STR

#second_nine = extract(<<~STR)
#  .#....###.....#..
#  ##...##...#.....#
#  ##...#......1234.
#  ..#.....X...5##..
#  ..#.9.....8....76
#STR

#third_nine = extract(<<~STR)
#  .8....###.....#..
#  56...9#...#.....#
#  34...7...........
#  ..2.....X....##..
#  ..1..............
#STR

#fourth_nine = extract(<<~STR)
#  ......234.....6..
#  ......1...5.....7
#  .................
#  ........X....89..
#  .................
#STR

# p first_nine
# p second_nine
# p third_nine
# p fourth_nine

th = enumerate(order_by_angle_from_north(best_visibles)).drop(199).first.pos

p th.x * 100 + th.y
