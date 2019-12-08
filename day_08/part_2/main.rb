def read_layers(width, height, input)
  chars = input.chars
  layer_size = width * height

  Array.new(chars.length / layer_size) do |layer_num|
    Array.new(height) do |row_num|
      chars[layer_num * layer_size + row_num * width, width]
    end
  end
end

def display_image(layer)
  layer.each do |row|
    print '|'
    row.each do |col|
      print col == '0' ? '▒' : ' '
    end
    print '|'
    print "\n"
  end
end

def merge_layer(layer1, layer2)
  layer1.zip(layer2).map do |layer1_row, layer2_row|
    layer1_row.zip(layer2_row).map do |c1, c2|
      c1 == '2' ? c2 : c1
    end
  end
end

display_image(read_layers(25, 6, $stdin.read).reduce { |l, r| merge_layer(l, r) })
