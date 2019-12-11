def asteroid_coords(input)
  input.split("\n").each_with_index.flat_map do |row, y|
    row.chars.each_with_index.map do |char, x|
      char == "#" ? [[x, y]] : []
    end
  end.flatten(1)
end

# Calculate the vector from coord 1 to another.
def diff((x1, y1), (x2, y2))
  [x1 - x2, y1 - y2]
end

# Turn [4, 2] into [2, 1], and [9, 3] into [3, 1] - this means that we treat all vectors in the
# same line as equal.
def normalise(x, y)
  gcd = x.gcd(y)
  gcd = 1 if gcd.zero?

  [x /= gcd, y /= gcd]
end

def visible_count(coords, start_coord)
  diffs = (coords - [start_coord]).map { |c| diff(c, start_coord) }

  # Ignore vectors "in the same line" - how many distinct coords can we see?
  diffs.group_by { |d| normalise(*d) }.size
end

input = $stdin.read
coords = asteroid_coords(input)

best_coord, best_count =
  coords.map { |coord| [coord, visible_count(coords, coord)] }.max_by { |_, c| c }

p best_coord
puts best_count
