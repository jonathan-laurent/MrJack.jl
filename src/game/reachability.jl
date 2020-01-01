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

function foreach_walkable_tile(f)
  nx, ny = size(INITIAL_BOARD)
  for y in 1:ny
    for x in 1:nx
      pos = (x, y)
      if STREET_TILES[pos...]
        f(pos)
      end
    end
  end
end

#####
##### Distance matrix with Floyd-Warshall
#####

function adjacency_matrix()
  nx, ny = size(INITIAL_BOARD)
  let A = zeros(UInt8, nx, ny, nx, ny)
    foreach_walkable_tile() do pos
      for dir in DIRECTIONS
        npos = pos .+ dir
        if valid_pos(INITIAL_BOARD, npos) && STREET_TILES[npos...]
          A[pos..., npos...] = 1
        end
      end
    end
    return A
  end
end

function distances_matrix()
  let W = adjacency_matrix()
    W[W .== 0] .= typemax(eltype(W)) >> 1
    foreach_walkable_tile() do k
      foreach_walkable_tile() do i
        foreach_walkable_tile() do j
          W[i..., j...] = min(W[i..., j...], W[i..., k...] + W[k..., j...])
        end
      end
    end
    return W
  end
end

const DISTANCES_MATRIX = distances_matrix()
