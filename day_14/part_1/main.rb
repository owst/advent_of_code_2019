require 'set'
require 'awesome_print'

Node = Struct.new(:weight, :name) do
  def self.parse(str)
    w, n = str.split(" ")

    new(w.to_i, n)
  end
end

def parse_reactions(input = nil)
  input ||= $stdin.read
  input.split("\n").map do |line|
    targets, source = line.split(" => ")

    [Node.parse(source), targets.split(",").map(&Node.method(:parse))]
  end.to_h
end

reactions = parse_reactions

def topological_order_each(edges)
  return to_enum(__method__, edges) unless block_given?

  in_edges = edges.flat_map do |source_name, (_, targets)|
    targets.map { |target| [target.name, source_name] }
  end.group_by(&:first).transform_values { |es| es.map { |e| e[1] } }

  to_visit = edges.keys.reject { |n| in_edges.key?(n) }

  until to_visit.empty?
    node = to_visit.shift

    yield node

    next unless edges.key?(node)

    edges.fetch(node)[1].each do |target|
      if in_edges[target.name].tap { |ie| ie.delete(node) }.empty?
        to_visit << target.name
        in_edges.delete(target.name)
      end
    end
  end
end

by_name = reactions.map do |source, targets|
  [source.name, [source, targets]]
end.to_h

res = topological_order_each(by_name).each_with_object({}) do |node_name, node_counts|
  if by_name.key?(node_name)
    source, targets = by_name.fetch(node_name)
    node_count = node_counts.fetch(node_name, 1)

    edge_count = (node_count.to_f / source.weight).ceil

    targets.map do |target|
      node_counts[target.name] ||= 0
      node_counts[target.name] += target.weight * edge_count
    end
  end
end


puts res.fetch("ORE")
