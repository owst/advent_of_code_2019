def read_input(str = nil)
  str ||= $stdin.read

  str.strip.chars.map(&:to_i) * 10_000
end

cells = read_input

skip_digits = cells.take(7).join.to_i
cells = cells.drop(skip_digits)

100.times do
  (cells.length - 2).downto(0) do |i|
    cells[i] = (cells[i] + cells[i + 1]) % 10
  end
end

puts cells.take(8).join
