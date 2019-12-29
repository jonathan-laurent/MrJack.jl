include("board.jl")

#####
##### Game State
#####

@enum GameStatus RUNNING JACK_ESCAPED JACK_CAPTURED TIMEOUT

# CK: common knowledge, HI: hidden information
@enum CharacterStatus UNKNOWN GUILTY INNOCENT_CK INNOCENT_HI

mutable struct Game
  status :: GameStatus
  board :: Board
  turn :: UInt8
  # Turn stage
  remchars :: Vector{Character} # Remaining characters
  prevchars :: Vector{Character} # Previously controlled characters
  # Watson lamp's direction
  wldir :: Direction
  # Who is who and who knows what?
  jack :: Character
  shcards :: Vector{Character} # Sherlock innocent cards
  cstatus :: Vector{CharacterStatus}
  # TODO: Cached information: where are things
end

function pick_characters()
  cs = Character[]
  while length(cs) < 4
    c = rand(CHARACTERS)
    if c ∉ cs
      push!(cs, c)
    end
  end
  return cs
end

function Game()
  status = RUNNING
  board = INITIAL_BOARD
  turn = 1
  remchars = pick_characters()
  prevchars = []
  wldir = DIRECTIONS[3]
  jack = rand(CHARACTERS)
  shcards = filter(!=(jack), CHARACTERS)
  cstatus = [UNKNOWN for c in CHARACTERS]
  return Game(
    status, board, turn, remchars, prevchars, wldir, jack, shcards, cstatus)
end

using JSON2
open("game.json", "w") do file
  JSON2.pretty(file, JSON2.write(Game()))
end
