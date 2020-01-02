#####
##### Game Actions
#####

abstract type AbstractAction end

# Chance actions

abstract type ChanceAction <: AbstractAction end

struct SelectJack <: ChanceAction
  jack :: Character
  function SelectJack(jack)
    @assert jack != NO_CHARACTER
    return new(jack)
  end
end

struct SelectPlayable <: ChanceAction
  playable :: Set{Character}
  function SelectPlayable(cs)
    @assert length(cs) == 4
    @assert all(!=(NO_CHARACTER), cs)
    return new(cs)
  end
end

struct SelectSherlockCard <: ChanceAction
  innocent :: Character
  function SelectSherlockCard(c)
    @assert c != NO_CHARACTER
    return new(c)
  end
end

# Play actions

struct SelectCharacter <: AbstractAction
  character :: Character
  function SelectCharacter(c)
    @assert c != NO_CHARACTER
    return new(c)
  end
end

struct UnselectCharacter <: AbstractAction end

struct FinishTurn <: AbstractAction end

struct MoveCharacter <: AbstractAction
  dst :: Position
  function MoveCharacter(dst)
    t = INITIAL_BOARD[dst...].type
    @assert walkable_tile(t) && t != EXIT
    return new(dst)
  end
end

struct Accusation <: AbstractAction
  accused :: Character
  function Accusation(c)
    @assert c != NO_CHARACTER
    return new(c)
  end
end

struct Escape <: AbstractAction
  dst :: Position
  function Escape(dst)
    @assert INITIAL_BOARD[dst...].type == EXIT
    return new(dst)
  end
end

# Power moves

abstract type PowerMove <: AbstractAction end

struct AskSherlock <: PowerMove end

struct ReorientWatsonLight <: PowerMove
  dir :: Direction
  function ReorientWatsonLight(dir)
    @assert dir ∈ DIRECTIONS
    return new(dir)
  end
end

struct MoveLamp <: PowerMove
  src :: Position
  dst :: Position
  function MoveLamp(src, dst)
    @assert INITIAL_BOARD[src...].type == LAMP
    @assert INITIAL_BOARD[dst...].type == LAMP
    return new(src, dst)
  end
end

struct MoveCops <: PowerMove
  src :: Position
  dst :: Position
  function MoveCops(src, dst)
    @assert INITIAL_BOARD[src...].type == EXIT
    @assert INITIAL_BOARD[dst...].type == EXIT
    return new(src, dst)
  end
end

struct MoveLid <: PowerMove
  src :: Position
  dst :: Position
  function MoveLid(src, dst)
    @assert INITIAL_BOARD[src...].type == WELL
    @assert INITIAL_BOARD[dst...].type == WELL
    return new(src, dst)
  end
end

struct SwapWilliamGull <: PowerMove
  other :: Character
  function SwapWilliamGull(c)
    @assert (c != WILLIAM_GULL) && (c != NO_CHARACTER)
    return new(c)
  end
end

struct UseWhistle <: PowerMove
  moves :: Vector{Tuple{Character, Position}}
  function UseWhistle(moves)
    cs = [m[1] for m in moves]
    dsts = [m[2] for m in moves]
    @assert length(cs) == length(unique(cs))
    @assert length(dsts) == length(unique(dsts))
    @assert all(STREET_TILES[m[2]...] for m in moves)
    @assert 1 <= length(moves) <= 3
    return new(moves)
  end
end
