Vector = Struct.new(:x, :y, :z) do
  def self.zero
    new(0, 0, 0)
  end

  def +(other)
    self.class.new(x + other.x, y + other.y, z + other.z)
  end

  def max(other)
    self.class.new([other.x, x.abs].max, [other.y, y.abs].max, [other.z, z.abs].max)
  end

  def pretty(max)
    c = ->(max_val) { "% #{max_val.zero? ? 1 : Math.log10(max_val).ceil + 2}d" }

    format("<x=#{c.call(max.x)}, y=#{c.call(max.y)}, z=#{c.call(max.z)}>", x, y, z)
  end
end

class Moon
  attr_reader :position, :velocity

  def initialize(position, velocity)
    @position = position
    @velocity = velocity
  end

  def self.parse(line)
    values = line.gsub(/[<>\s]+/, '').split(",").map do |assign|
      var, value = assign.split("=")

      [var, value.to_i]
    end.to_h

    new(Vector.new(values.fetch("x"), values.fetch("y"), values.fetch("z")), Vector.zero)
  end

  def pretty(max_pos, max_vel)
    "pos=#{@position.pretty(max_pos)}, vel=#{@velocity.pretty(max_vel)}"
  end

  def step
    self.class(@position + @velocity, @velocity)
  end

  def apply_gravity(other)
    pos = position
    opos = other.position

    new(p, velocity + Vector.new(pos.x <=> opos.x, pos.y <=> opos.y, pos.z <=> opos.z))
  end
end

def read_input(input = nil)
  input ||= $stdin.read

  input.split("\n").map { |line| Moon.parse(line) }
end

def print(moons)
  maxes = moons.reduce([Vector.zero, Vector.zero]) do |(max_pos, max_vel), moon|
    [moon.position.max(max_pos), moon.velocity.max(max_vel)]
  end

  moons.each do |moon|
    puts moon.pretty(*maxes)
  end
end

initial = read_input(<<~STR)
  <x=-1, y=0, z=2>
  <x=2, y=-10, z=-7>
  <x=4, y=-8, z=8>
  <x=3, y=5, z=-1>
STR

print(initial)

def apply_gravity
end

def apply_velocity
end

def time_step
  apply_gravity
  apply_velocity
end
