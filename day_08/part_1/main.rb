def read_layers(width, height, input)
  chars = input.chars
  layer_size = width * height

  Array.new(chars.length / layer_size) do |layer_num|
    Array.new(height) do |row_num|
      chars[layer_num * layer_size + row_num * width, width]
    end
  end
end

read_layers(25, 6, $stdin.read).min_by { |l|
  l.flatten.count { |c| c == '0' }
}.yield_self do |l|
  digit_counts = l.flatten.group_by(&:itself).transform_values(&:length)
  puts digit_counts.fetch("1") * digit_counts.fetch("2")
end
