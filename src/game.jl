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
  # Cached information: where are things
  char_pos :: Vector{Position}
  cops_pos :: Set{Position}
  anon_lamp_pos :: Set{Position}
  numbered_lamp_pos :: Vector{Union{Position, Nothing}} # Indices: 1-4
  lid_pos :: Set{Position}

  function Game(
      status, board, turn, remchars, prevchars, wldir, jack, shcards, cstatus)
    # Dummy initialization for the cache
    char_pos = Position[(0, 0) for c in CHARACTERS]
    cops_pos = Set()
    anon_lamp_pos = Set()
    numbered_lamp_pos = Union{Position, Nothing}[nothing for i in 1:4]
    lid_pos = Set()
    g = new(
      status, board, turn, remchars, prevchars, wldir, jack, shcards, cstatus,
      char_pos, cops_pos, anon_lamp_pos, numbered_lamp_pos, lid_pos)
    update_cache!(g)
    assert_state_coherence(g)
    return g
  end
end

function valid_pos(board, pos)
  nx, ny = size(board)
  x, y = pos
  return (1 <= x <= nx) && (1 <= y <= ny) &&  (x % 2 != y % 2)
end

function assert_board_coherence(g)
  # Assert that all items listed in cache are in the right place (soundness)
  for (i, pos) in enumerate(g.char_pos)
    @assert g.board[pos...].character == i
  end
  for pos in g.cops_pos
    t = g.board[pos...]
    @assert t.type == EXIT
    @assert !t.activated
  end
  for pos in g.anon_lamp_pos
    t = g.board[pos...]
    @assert t.type == LAMP
    @assert t.activated
  end
  for (i, pos) in enumerate(g.numbered_lamp_pos)
    if !isnothing(pos)
      t = g.board[pos...]
      @assert t.type == LAMP
      @assert t.activated
      @assert t.lampid == i
    end
  end
  for pos in g.lid_pos
    t = g.board[pos...]
    @assert t.type == WELL
    @assert !t.activated
  end
  # Assert that the cache is complete
  nx, ny = size(g.board)
  for x in 1:nx
    for y in 1:ny
      pos = (x, y)
      t = g.board[x, y]
      @assert (t.type != INVALID) == valid_pos(g.board, pos)
      if t.character > 0
        @assert g.char_pos[t.character] == pos
      end
      if t.type == EXIT && !t.activated
        @assert pos ∈ g.cops_pos
      end
      if t.type == LAMP && t.activated
        if t.lampid > 0
          @assert g.numbered_lamp_pos[t.lampid] == pos
        else
          @assert pos ∈ g.anon_lamp_pos
        end
      end
      if t.type == WELL && !t.activated
        @assert pos ∈ g.lid_pos
      end
    end
  end
end

function update_cache!(g)
  nx, ny = size(g.board)
  for x in 1:nx
    for y in 1:ny
      pos = (x, y)
      t = g.board[x, y]
      if t.character > 0
        g.char_pos[t.character] = pos
      end
      if t.type == EXIT && !t.activated
        push!(g.cops_pos, pos)
      end
      if t.type == LAMP && t.activated
        if t.lampid > 0
          g.numbered_lamp_pos[t.lampid] = pos
        else
          push!(g.anon_lamp_pos, pos)
        end
      end
      if t.type == WELL && !t.activated
        push!(g.lid_pos, pos)
      end
    end
  end
end

function assert_state_coherence(g)
  assert_board_coherence(g)
  for i in 1:4
    @assert (g.turn > i) == isnothing(g.numbered_lamp_pos[i])
  end
  @assert length(g.remchars) + length(g.prevchars) == 4
  @assert g.jack ∉ g.shcards
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

#####
##### Board Primitives
#####

#####
##### Micro Actions
#####

@enum ActionType MoveCharacter MoveLid MoveLamp OrientWatsonLamp

struct Action

end

#####
##### Implementing game rules
#####

#=
In what situations action to take?
  - Choose character
  - Move character
  - Use special power

Move character from X to Y (flag for arrest?)
Move lamp
Change W. lamp orientation
Move cops
Move well lid
Cop: move three in total?
=#

#####
##### Exporting in JSON
#####

using JSON2
open("game.json", "w") do file
  JSON2.pretty(file, JSON2.write(Game()))
end
