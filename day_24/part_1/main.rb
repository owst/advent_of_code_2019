require 'set'

def input(str = nil)
  str ||= ARGF.read

  str.split("\n").map do |line|
    line.chars
  end
end

class World
  def initialize(state)
    @state = state
  end

  def evolve
    empty_row = ['.'] * @state.first.size

    @state = [empty_row, *@state, empty_row].each_cons(3).map do |prev_row, curr_row, next_row|
      zipped = [prev_row, curr_row, next_row].reduce(&:zip).map(&:flatten)

      empty_slice = ['.'] * 3

      [empty_slice, *zipped, empty_slice].each_cons(3).map do |(_, l, _), (u, c, d), (_, r, _)|
        count = [l, u, d, r].count { |c| c == '#' }

        if c == '#'
          count == 1 ? '#' : '.'
        else
          count.between?(1, 2) ? '#' : '.'
        end
      end
    end
  end

  def biodiversity_rating
    @state.flatten.each_with_index.select { |c, _| c == '#' }.map do |_, i|
      2 ** i
    end.sum
  end

  def draw
    @state.map(&:join).join("\n")
  end
end

world = World.new(input)
seen_worlds = Set.new

loop do
  puts world.draw

  if seen_worlds.include?(world.draw)
    break
  end

  seen_worlds << world.draw

  world.evolve
  puts

  sleep 0.01
end

puts "Biodiversity rating: #{world.biodiversity_rating}"
