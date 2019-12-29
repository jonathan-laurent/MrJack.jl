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
  active_wells :: Set{Position}
  function Game(
      status, board, turn, remchars, prevchars, wldir, jack, shcards, cstatus)
    # Dummy initialization for the cache
    char_pos = Position[(0, 0) for c in CHARACTERS]
    cops_pos = Set()
    anon_lamp_pos = Set()
    numbered_lamp_pos = Union{Position, Nothing}[nothing for i in 1:4]
    lid_pos = Set()
    active_wells = Set()
    g = new(
      status, board, turn, remchars, prevchars, wldir, jack, shcards, cstatus,
      char_pos, cops_pos, anon_lamp_pos, numbered_lamp_pos, lid_pos,
      active_wells)
    init_cache!(g)
    assert_state_coherence(g)
    return g
  end
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
  for pos in g.active_wells
    t = g.board[pos...]
    @assert t.type == WELL
    @assert t.activated
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
      if t.type == WELL
        if t.activated
          @assert pos ∈ g.active_wells
        else
          @assert pos ∈ g.lid_pos
        end
      end
    end
  end
end

function init_cache!(g)
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
      if t.type == WELL
        if t.activated
          push!(g.active_wells, pos)
        else
          push!(g.lid_pos, pos)
        end
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

#####
##### Access utilities
#####

get_activated(g, pos) = g.board[pos...].activated
get_lampid(g, pos) = g.board[pos...].lampid
get_type(g, pos) = g.board[pos...].type
get_character(g, pos) = g.board[pos...].character

function set_activated!(g, pos, activated)
  t = g.board[pos...]
  g.board[pos...] = Tile(t.type, activated, t.lampid, t.character)
end

function set_lampid!(g, pos, lampid)
  t = g.board[pos...]
  g.board[pos...] = Tile(t.type, t.activated, lampid, t.character)
end

function set_character!(g, pos, character)
  t = g.board[pos...]
  g.board[pos...] = Tile(t.type, t.activated, t.lampid, character)
end

#####
##### Board Primitives
#####

function move_character!(g, c, newpos)
  curpos = g.char_pos[c]
  set_character!(g, curpos, 0x0)
  @assert get_character(g, newpos) == 0x0 # destination must be free
  set_character!(g, newpos, c)
  g.char_pos[c] = newpos
end

function swap_activation(g, src, dst, type, v)
  @assert get_type(g, src) == type
  @assert get_type(g, dst) == type
  @assert get_activated(g, src) == v
  @assert get_activated(g, dst) == !v
  set_activated!(g, src, !v)
  set_activated!(g, dst, v)
end

function move_cops(g, src, dst)
  swap_activation(g, src, dest, EXIT, false)
  delete!(g.cops_pos, src)
  push!(g.cops_pos, dst)
end

function move_lid(g, src, dst)
  swap_activation(g, src, dst, WELL, false)
  delete!(g.lid_pos, src)
  push!(g.active_wells, src)
  push!(g.lid_pos, dst)
  delete!(g.active_wells, dst)
end

function move_lamp(g, src, dst)
  swap_activation(g, src, dst, LAMP, true)
  id = get_lampid(g, src)
  if id > 0
    # The lamp is numbered
    set_lampid!(g, src, 0x0)
    set_lampid!(g, dst, id)
    g.numbered_lamp_pos[id] = dst
  else
    # The lamp is anonymous
    delete!(g.anon_lamp_pos, src)
    push!(g.anon_lamp_pos, dst)
  end
end

function switch_off_numbered_lamp!(g, num)
  @assert 1 <= num <= 4
  pos = g.numbered_lamp_pos[num]
  @assert !isnothing(pos)
  g.numbered_lamp_pos[num] = nothing
  @assert get_activated(g, pos) == true
  @assert get_lampid(g, pos) == num
  set_activated!(g, pos, false)
  set_lampid!(g, pos, 0x0)
end

function test_moves()
  g = Game()
  assert_state_coherence(g)
  shpos = g.char_pos[SHERLOCK_HOLMES]
  # Move a character
  move_character!(g, SHERLOCK_HOLMES, shpos .+ TR)
  assert_state_coherence(g)
  # Move numbered lamp L3
  posl3 = g.numbered_lamp_pos[3]
  move_lamp(g, posl3, posl3 .+ TR .+ TR .+ BR)
  assert_state_coherence(g)
  # Move an anonymous lamp
  move_lamp(g, g.char_pos[INSPECTOR_LESTRADE] .+ BR, posl3)
  assert_state_coherence(g)
  # Move a lid
  move_lid(g, g.numbered_lamp_pos[1] .+ BB, g.numbered_lamp_pos[4] .+ TR)
  assert_state_coherence(g)
  # Switch L1 off
  switch_off_numbered_lamp!(g, 1)
  g.turn = 2
  assert_state_coherence(g)
end

#####
##### Initial State
#####

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
  board = initial_board()
  turn = 1
  remchars = pick_characters()
  prevchars = []
  wldir = BR
  jack = rand(CHARACTERS)
  shcards = filter(!=(jack), CHARACTERS)
  cstatus = [UNKNOWN for c in CHARACTERS]
  return Game(
    status, board, turn, remchars, prevchars, wldir, jack, shcards, cstatus)
end

#####
##### Compute Available Moves
#####

# Reachable in 1-4 moves
# Reachable in 1-3 moves
# Reachable in exactly k moves

function reachable_zero(pos)
  @assert valid_pos(INITIAL_BOARD, pos)
  R = falses(size(INITIAL_BOARD))
  R[pos...] = true
  return R
end

function reachable_transition(R, active_wells; through_houses=false)
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
            if walkable_tile(t) || (through_houses && t == HOUSE)
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

function reachable_positions(pos, n, active_wells; through_houses=false)
  Rs = [reachable_zero(pos)]
  for i in 1:n
    Rnext = reachable_transition(
      Rs[end], active_wells, through_houses=through_houses)
    push!(Rs, Rnext)
  end
  R = reduce(Rs) do R1, R2
    R1 .| R2
  end
  # Cannot stay in place
  R[pos...] = false
  return R
end

function test_reachability()
  g = Game()
  R = reachable_positions(g.char_pos[SERGENT_GOODLEY], 3, g.active_wells)
  cR = count(==(true), R)
  return cR
end

#####
##### Main
#####

test_moves()
test_reachability()

#=
using JSON2
open("game.json", "w") do file
  JSON2.pretty(file, JSON2.write(Game()))
end
=#
