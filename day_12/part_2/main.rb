require "set"

Vector = Struct.new(:x, :y, :z) do
  def self.zero
    new(0, 0, 0)
  end

  def +(other)
    self.class.new(x + other.x, y + other.y, z + other.z)
  end

  def *(other)
    self.class.new(x * other.x, y * other.y, z * other.z)
  end

  def abs_max(other)
    self.class.new(*to_a.map(&:abs).zip(other.to_a.map(&:abs)).map(&:max))
  end

  def pretty(max)
    digit_count = ->(val) { Math.log10(val).floor + 1 }

    # +1 to account for (optional) leading "-" in overal width
    c = ->(max_val) { "% #{max_val.zero? ? 1 : digit_count.call(max_val) + 1}d" }

    format("<x=#{c.call(max.x)}, y=#{c.call(max.y)}, z=#{c.call(max.z)}>", x, y, z)
  end
end

Moon = Struct.new(:position, :velocity) do
  def self.parse(line)
    values = line.gsub(/[<>\s]+/, '').split(",").map do |assign|
      var, value = assign.split("=")

      [var, value.to_i]
    end.to_h

    new(Vector.new(values.fetch("x"), values.fetch("y"), values.fetch("z")), Vector.zero)
  end

  def pretty(max_pos, max_vel)
    "pos=#{position.pretty(max_pos)}, vel=#{velocity.pretty(max_vel)}"
  end

  def apply_velocity
    self.class.new(position + velocity, velocity)
  end

  def apply_gravity(other, dimension)
    pos = position
    opos = other.position

    # Apply the update for only a single dimension by multiplying two of three positions by zero.
    selection = Vector.new(*([0, 0, 0].tap { |sel| sel[%w[x y z].index(dimension)] = 1 }))
    update = Vector.new(opos.x <=> pos.x, opos.y <=> pos.y, opos.z <=> pos.z)

    self.class.new(pos, velocity + (selection * update))
  end
end

def read_input(input = nil)
  input ||= $stdin.read

  input.split("\n").map { |line| Moon.parse(line) }
end

def print(moons)
  maxes = moons.reduce([Vector.zero, Vector.zero]) do |(max_pos, max_vel), moon|
    [moon.position.abs_max(max_pos), moon.velocity.abs_max(max_vel)]
  end

  moons.each { |moon| puts moon.pretty(*maxes) }
end

state = read_input

def find_repeat(dimension, state)
  seen = Set.new([])
  steps = 0

  until seen.include?(state)
    p steps % 100 == 0
    seen << state

    state = state.map do |moon|
      (state - [moon]).reduce(moon) { |l, r| l.apply_gravity(r, dimension) }.apply_velocity
    end

    steps += 1
  end

  steps
end

p %w[x y z].map { |dim| find_repeat(dim, state) }.reduce(&:lcm)
