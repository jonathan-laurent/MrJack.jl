#####
##### Reachability
#####

function reachable_zero(pos)
  @assert valid_pos(INITIAL_BOARD, pos)
  R = falses(size(INITIAL_BOARD))
  R[pos...] = true
  return R
end

function reachable_transition(R, active_wells; all_tiles=false)
  nx, ny = size(INITIAL_BOARD)
  Rnext = falses(nx, ny)
  for x in 1:nx
    for y in 1:ny
      pos = (x, y)
      if R[x, y] # position was reachable the turn before
        # Move to a neighbor tile
        for dir in DIRECTIONS
          newpos = pos .+ dir
          if valid_pos(INITIAL_BOARD, newpos)
            t = INITIAL_BOARD[newpos...].type
            if walkable_tile(t) || (all_tiles && t == game_tile(t))
              Rnext[newpos...] = true
            end
          end
        end
        # Take a well
        if pos ∈ active_wells
          for dst in active_wells
            Rnext[dst...] = true
          end
        end
      end
    end
  end
  return Rnext
end

function reachable_positions(pos, n, active_wells; all_tiles=false)
  Rs = [reachable_zero(pos)]
  for i in 1:n
    Rnext = reachable_transition(
      Rs[end], active_wells, all_tiles=all_tiles)
    push!(Rs, Rnext)
  end
  R = reduce(Rs) do R1, R2
    R1 .| R2
  end
  # The character has to end on a street tile
  R .&= STREET_TILES
  # Cannot stay in place
  R[pos...] = false
  return R
end

function test_reachability()
  g = Game()
  R = reachable_positions(g.char_pos[SERGENT_GOODLEY |> Int], 3, g.active_wells)
  cR = count(==(true), R)
  return cR
end
