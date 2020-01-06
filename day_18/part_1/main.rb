require 'set'

def parse(str = nil)
  str ||= $stdin.read

  parsed = str.split("\n").each_with_index.map do |line, row|
    col_map = line.chars.each_with_index.map do |cell, col|
      [col, cell]
    end.to_h

    [row, col_map]
  end.to_h

  [parsed.map { |_, cells| cells.count { |_, c| /[a-z]/.match?(c) } }.sum, parsed]
end

Path = Struct.new(:x, :y, :path_length, :collected_keys) do
  OFFSETS = [
    [-1, 0],
    [1, 0],
    [0, -1],
    [0, 1]
  ].freeze

  def next_steps(parsed_map, visited)
    OFFSETS.each do |dx, dy|
      x2 = x + dx
      y2 = y + dy

      next_cell = parsed_map.fetch(y2, {}).fetch(x2, '#')

      next if next_cell == '#'

      new_collected_keys = if /[a-z]/.match?(next_cell)
                             collected_keys + [next_cell]
                           else
                             collected_keys
                           end
      next if visited.include?([x2, y2, new_collected_keys])

      next unless next_cell == '.' || next_cell == '@' || new_collected_keys.include?(next_cell.downcase)

      yield self.class.new(x2, y2, path_length + 1, new_collected_keys)
    end
  end
end

def init_path(parsed)
  parsed.each do |y, row|
    row.each do |x, cell|
      return Path.new(x, y, 0, Set.new([])) if cell == '@'
    end
  end
end

def bsf_collect_all(input = nil)
  key_count, parsed = parse(input)

  paths = []
  paths << init_path(parsed)

  visited = Set.new({})
  loop do
    path = paths.shift

    return path if path.collected_keys.size == key_count

    path.next_steps(parsed, visited) do |ns|
      visited << [ns.x, ns.y, ns.collected_keys]

      paths.push(ns)
    end
  end
end

def shortest_path_length(input = nil)
  bsf_collect_all(input).path_length
end

#p 132 == shortest_path_length(<<~STR)
#  ########################
#  #...............b.C.D.f#
#  #.######################
#  #.....@.a.B.c.d.A.e.F.g#
#  ########################
#STR

#p 136 == shortest_path_length(<<~STR)
#  #################
#  #i.G..c...e..H.p#
#  ########.########
#  #j.A..b...f..D.o#
#  ########@########
#  #k.E..a...g..B.n#
#  ########.########
#  #l.F..d...h..C.m#
#  #################
#STR

#p 81 == shortest_path_length(<<~STR)
#  ########################
#  #@..............ac.GI.b#
#  ###d#e#f################
#  ###A#B#C################
#  ###g#h#i################
#  ########################
#STR

p shortest_path_length
