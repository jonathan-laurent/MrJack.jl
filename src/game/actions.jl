#####
##### Game Actions
#####

abstract type AbstractAction end

# Chance actions

abstract type ChanceAction <: AbstractAction end

struct SelectJack <: ChanceAction
  jack :: Character
end

struct SelectPlayable <: ChanceAction
  playable :: Vector{Character}
end

struct SelectSherlockCard <: ChanceAction
  innocent :: Character
end

# Play actions

struct SelectCharacter <: AbstractAction
  character :: Character
end

struct MoveCharacter <: AbstractAction
  character :: Character
  dst :: Position
end

struct Accusation <: AbstractAction
  accuser :: Character
  accused :: Character
end

# Power moves

abstract type PowerMove <: AbstractAction end

struct AskSherlock <: PowerMove end

struct ReorientWatsonLight <: PowerMove
  dir :: Direction
end

struct MoveLamp <: PowerMove
  src :: Position
  dst :: Position
end

struct MoveCops <: PowerMove
  src :: Position
  dst :: Position
end

struct MoveLid <: PowerMove
  src :: Position
  dst :: Position
end

struct SergentGoodley <: PowerMove
  moves :: Vector{Tuple{Character, Position}}
end

struct SwapWilliamGull <: PowerMove
  other :: Character
end
