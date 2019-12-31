


#####
##### Initial State
#####

function pick_characters()
  cs = Set{Character}()
  while length(cs) < 4
    c = rand(CHARACTERS)
    if c ∉ cs
      push!(cs, c)
    end
  end
  return cs
end

function Game()
  status = SELECTING_CHARACTER
  board = initial_board()
  turn = 1
  remchars = pick_characters()
  prevchars = []
  selected = NO_CHARACTER
  used_power = false
  used_move = false
  wldir = BR
  jack = rand(CHARACTERS)
  shcards = Set{Character}(filter(!=(jack), CHARACTERS))
  cstatus = [UNKNOWN for c in CHARACTERS]
  visible = falses(length(CHARACTERS)) # Dummy
  g = Game(
    status, board, turn, remchars, prevchars, selected, used_power, used_move,
    wldir, jack, shcards, cstatus, visible)
  update_visible!(g)
  return g
end
