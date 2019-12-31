#####
##### Visibility
#####

function make_neighborhood_visible!(V, pos)
  for dir in DIRECTIONS
    npos = pos .+ dir
    if valid_pos(INITIAL_BOARD, npos)
      V[npos...] = true
    end
  end
end

function use_watson_light!(V, wpos, wldir)
  pos = wpos .+ wldir
  while walkable_tile(INITIAL_BOARD[pos...].type)
    V[pos...] = true
    pos = pos .+ wldir
  end
end

function visible_by_lamp(game)
  V = falses(size(game.board))
  for pos in game.anon_lamp_pos
    make_neighborhood_visible!(V, pos)
  end
  for pos in game.numbered_lamp_pos
    if !isnothing(pos)
      make_neighborhood_visible!(V, pos)
    end
  end
  wlpos = game.char_pos[JOHN_WATSON |> Int]
  use_watson_light!(V, wlpos, game.wldir)
  return V
end

function visible_by_someone(game)
  V = falses(size(game.board))
  for pos in game.char_pos
    make_neighborhood_visible!(V, pos)
  end
  return V
end

visibility_mask(game) = visible_by_lamp(game) .| visible_by_someone(game)

function update_visible!(game)
  V = visibility_mask(game)
  for c in CHARACTERS
    pos = game.char_pos[Int(c)]
    game.visible[Int(c)] = V[pos...]
  end
end
