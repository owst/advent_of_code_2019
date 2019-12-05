def all_possibles
  ('000000'..'999999')
end

def two_adjacent_digits_equal?(str)
  str =~ /(\d)\1/
end

def no_adjacent_digit_decrease?(str)
  str.chars.each_cons(2).all? { |c1, c2| c1 <= c2 }
end

def in_range?(str)
  ('108457'..'562041').cover?(str)
end

p all_possibles.count { |s|
  in_range?(s) && no_adjacent_digit_decrease?(s) && two_adjacent_digits_equal?(s)
}
