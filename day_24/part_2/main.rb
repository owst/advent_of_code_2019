require 'set'

def input(str = nil)
  str ||= ARGF.read

  str.split("\n").map(&:chars)
end

class World
  MIN = 0
  MAX = 4

  def initialize(cell_chars)
    @state = {
      0 => cell_chars.each_with_index.flat_map do |row, y|
        row.each_with_index.map do |cell, x|
          [[x, y], cell == '#']
        end
      end.to_h
    }
  end

  def populated?(level, x, y)
    (@state[level] || {})[[x, y]] || false
  end

  def neighbours(level, x, y)
    [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1]
    ].flat_map do |xd, yd|
      nx = x + xd
      ny = y + yd

      if nx.negative?|| nx > MAX
        [[level - 1, nx.negative? ? 1 : 3, 2]]
      elsif ny.negative? || ny > MAX
        [[level - 1, 2, ny.negative? ? 1 : 3]]
      elsif nx == 2 && ny == 2
        new_level = level + 1

        if xd.nonzero?
          Array.new(5) { |nested_y| [new_level, x == 3 ? MAX : MIN, nested_y] }
        else
          Array.new(5) { |nested_x| [new_level, nested_x, y == 3 ? MAX : MIN] }
        end
      else
        [[level, nx, ny]]
      end
    end
  end

  def populated_neighbour_count(l, x, y)
    return 0 if x == 2 && y == 2

    neighbours(l, x, y).count { |l2, x2, y2| populated?(l2, x2, y2) }
  end

  def evolve
    new_level = (MIN..MAX).to_a.product((MIN..MAX).to_a).map { |a| [a, false] }.to_h

    new_min = @state.keys.min - 1
    new_max = @state.keys.max + 1

    @state = @state.merge(new_min => new_level, new_max => new_level).map do |level, cells|
      new_cells = cells.map do |coords, populated|
        [coords, populated_neighbour_count(level, *coords).between?(1, populated ? 1 : 2)]
      end.to_h

      [level, new_cells]
    end.to_h.reject { |k, vs| [new_min, new_max].include?(k) && vs.values.none? }
  end

  def bug_count
    @state.values.map do |cells|
      cells.values.count { |c| c }
    end.sum
  end
end

world = World.new(input)

200.times do |i|
  world.evolve
  print "\rEvolved #{i + 1} times"
end

puts
p world.bug_count
