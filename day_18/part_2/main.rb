require 'set'

def find_start_coords(lines, pattern)
  lines.each_with_index.flat_map do |line, y|
    line.chars.each_with_index.map do |char, x|
      [x, y] if pattern.match?(char)
    end
  end.compact
end

#original_map = <<~MAP.split("\n")
#  #######
#  #a.#Cd#
#  ##...##
#  ##.@.##
#  ##...##
#  #cB#Ab#
#  #######
#MAP

#transformed_map = <<~TRANSFORMED_MAP.split("\n")
#  #######
#  #a.#Cd#
#  ##@#@##
#  #######
#  ##@#@##
#  #cB#Ab#
#  #######
#TRANSFORMED_MAP

#transform(original_map) == transformed_map

#transform(transform(original_map)) == transformed_map
def transform(lines)
  starts = find_start_coords(lines, /@/)

  return lines unless starts.size == 1

  x, y = starts.first

  lines.each_with_index.map do |line, i|
    if [y - 1, y + 1].include?(i)
      line[0, x - 1] + '@#@' + line[(x + 2..-1)]
    elsif i == y
      line[0, x - 1] + '###' + line[(x + 2..-1)]
    else
      line
    end
  end
end

def parse_map(lines)
  parsed = lines.each_with_index.map do |line, row|
    col_map = line.chars.each_with_index.map do |cell, col|
      [col, cell]
    end.to_h

    [row, col_map]
  end.to_h

  [parsed.map { |_, cells| cells.count { |_, c| /[a-z]/.match?(c) } }.sum, parsed]
end

def unlocked_door?(char, collected_keys)
  char =~ /[A-Z]/ && collected_keys.include?(char.downcase)
end

def bfs_for_keys(map, start)
  visited = Set.new([start])

  key_distances = {}

  queue = [[start, 0, Set.new([])]]

  until queue.empty?
    (x, y), length, required_keys = queue.shift

    [[0, -1], [0, 1], [-1, 0], [1, 0]].each do |dx, dy|
      x2 = x + dx
      y2 = y + dy

      next_char = map.fetch(y2).fetch(x2)

      next if visited.include?([x2, y2])

      visited << [x2, y2]

      if next_char == '#'
        next
      elsif next_char =~ /[a-z]/
        key_distances[next_char] = [[x2, y2], length + 1, required_keys]
      end

      additional_required_keys = next_char =~ /[A-Z]/i ? [next_char.downcase] : []
      queue << [[x2, y2], length + 1, required_keys | additional_required_keys]
    end
  end

  key_distances
end

lines = transform(
  $stdin.read.split("\n")
)

starts = find_start_coords(lines, /@/)
key_count, map = parse_map(lines)
key_to_key_moves = find_start_coords(lines, /[a-z@]/).map { |k| [k, bfs_for_keys(map, k)] }.to_h

def available_moves(key_to_key_moves, position, collected_keys)
  key_to_key_moves[position].select { |next_key, (_, _, required_keys)|
    !collected_keys.include?(next_key) && required_keys <= collected_keys
  }
end

def search(map, key_to_key_moves, positions, collected_keys, cache = {})
  cache[[positions, collected_keys]] ||=
    begin
      p cache.size if cache.size % 100 == 0

      next_moves_by_position = positions.map do |position|
        [position, available_moves(key_to_key_moves, position, collected_keys)]
      end.to_h

      if next_moves_by_position.all? { |_, moves| moves.empty? }
        0
      else
        next_moves_by_position.flat_map do |position, next_moves|
          next_moves.map do |next_key, (new_pos, distance, _required_keys)|
            # I tried both of the following updates, but this led to massively more positions being
            # explored (~124K vs ~22K)
            # new_positions = positions - [position] + [new_pos]
            # new_positions = [new_pos] + positions - [position]
            new_positions = positions.map { |pos| pos == position ? new_pos : pos }
            new_collected_keys = collected_keys + [next_key]
            distance + search(map, key_to_key_moves, new_positions, new_collected_keys, cache)
          end
        end.min
      end
    end
end

p search(map, key_to_key_moves, starts, Set.new([]))
