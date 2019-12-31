include("board.jl")

#####
##### Game Status
#####

"""
    GameStatus

The game can be in the following status.

# Endgame Status

  - `JACK_ESCAPED`: Jack escaped and won the game
  - `JACK_CAPTURED`: the detectives captures Mr. Jack
  - `WRONG_ACCUSATION`: the incorrect person was accused and Mr. Jack won
  - `TIMEOUT`: the detectives failed to capture Mr. Jack within 8 turns

# Chance Status

These status are used to indicate that a random decision is waiting to be made.

  - `PICKING_JACK`: Jack has to be picked among all possible characters.
     Answer with an action of type [`SelectJack`](@ref).
  - `PICKING_PLAYABLE_CHARACTERS`: Four playable characters have to be picked
     randomly. Answer with an action of type [`SelectPlayable`](@ref).
  - `PICKING_SHERLOCK_CARD`: A card proving a player innocent has to be drawn
     from the set described by `sherlock_cards(state)`.
     Answer with an action of type [`SelectSherlockCard`](@ref).

# Playing Characters

When either the detectives or Sherlock has to play and the game is still
running, the status is `SELECTING_CHARACTER` or `PLAYING_CHARACTER`.

At first, the status should be `SELECTING_CHARACTER`.
  - To access the current player, use `current_player(state)`
  - To access the set of playable characters, use `playable_characters(state)`
This status should be answered with action [`SelectCharacter`](@ref).

After this, the status should become `PLAYING_CHARACTER`. This status
must be answered by actions of type [`MoveCharacter`](@ref),
[`PowerMove`](@ref) or [`Accusation`](@ref).
  - To know if the character already used its power, use `power_used(state)`
  - To know if the character already moves, use `used_move(state)`
"""
@enum GameStatus begin
  # Endgames
  JACK_ESCAPED
  JACK_CAPTURED
  TIMEOUT
  # Chance states
  PICKING_JACK
  PICKING_PLAYABLE_CHARACTERS
  PICKING_SHERLOCK_CARD
  # Play states
  SELECTING_CHARACTER
  PLAYING_CHARACTER
end

@enum Player begin
  DETECTIVES
  JACK
  CHANCE
end

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

#####
##### Game State
#####

# CK: common knowledge, HI: hidden information
@enum CharacterStatus UNKNOWN GUILTY INNOCENT_CK INNOCENT_HI

mutable struct Game
  status :: GameStatus
  board :: Board
  turn :: UInt8
  # Turn stage
  remchars :: Set{Character} # Remaining characters
  prevchars :: Vector{Character} # Previously controlled characters
  selected :: Character # Only meaningful if `status == PLAYING_CHARACTER`
  used_power :: Bool # idem
  used_move :: Bool # idem
  # Watson lamp's direction
  wldir :: Direction
  # Who is who and who knows what?
  jack :: Character
  shcards :: Set{Character} # Sherlock innocent cards
  cstatus :: Vector{CharacterStatus} # Indices: character numbers
  visible :: BitVector # idem
  # Cached information: where are things
  char_pos :: Vector{Position}
  cops_pos :: Set{Position}
  anon_lamp_pos :: Set{Position}
  numbered_lamp_pos :: Vector{Union{Position, Nothing}} # Indices: 1-4
  lid_pos :: Set{Position}
  active_wells :: Set{Position}
  function Game(
      status, board, turn, remchars, prevchars, selected, used_power, used_move,
      wldir, jack, shcards, cstatus, visible)
    # Dummy initialization for the cache
    char_pos = Position[(0, 0) for c in CHARACTERS]
    cops_pos = Set()
    anon_lamp_pos = Set()
    numbered_lamp_pos = Union{Position, Nothing}[nothing for i in 1:4]
    lid_pos = Set()
    active_wells = Set()
    g = new(
      status, board, turn, remchars, prevchars, selected, used_power, used_move,
      wldir, jack, shcards, cstatus, visible,
      char_pos, cops_pos, anon_lamp_pos,
      numbered_lamp_pos, lid_pos, active_wells)
    init_cache!(g)
    assert_state_coherence(g)
    return g
  end
end

sherlock_cards(game) = game.shcards
used_move(game) = game.used_move
used_power(game) = game.used_power

function is_chance_node(game)
  return game.status ∈ [
    PICKING_JACK,
    PICKING_PLAYABLE_CHARACTERS,
    PICKING_SHERLOCK_CARD]
end

function current_player(game)
  @assert game.status == PLAYING
  n = length(sh.prevchars) + 1 # Turn stage as a number in {1..4}
  @assert 1 <= n <= 4
  if game.turn % 2 == 1
    return (n == 1 || n == 4) ? DETECTIVES : JACK
  else
    return (n == 2 || n == 3) ? DETECTIVES : JACK
  end
end

function playable_characters(game)
  @assert game.status == PLAYING
  @assert !isempty(game.remchars)
  return game.remchars
end

function assert_board_coherence(g)
  # Assert that all items listed in cache are in the right place (soundness)
  for (i, pos) in enumerate(g.char_pos)
    @assert g.board[pos...].character == Character(i)
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
      if t.character != NO_CHARACTER
        @assert g.char_pos[t.character |> Int] == pos
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
      if t.character != NO_CHARACTER
        g.char_pos[t.character |> Int] = pos
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
  curpos = g.char_pos[c |> Int]
  set_character!(g, curpos, NO_CHARACTER)
  @assert get_character(g, newpos) == NO_CHARACTER # destination must be free
  set_character!(g, newpos, c)
  g.char_pos[c |> Int] = newpos
end

function swap_characters(g, c1, c2)
  tmp = (1, 1) # Inaccessible position that is only used for the switch
  pos1 = g.char_pos[c1 |> Int]
  pos2 = g.char_pos[c2 |> Int]
  move_character!(g, c1, tmp)
  move_character!(g, c2, pos1)
  move_character!(g, c1, pos2)
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
  shpos = g.char_pos[SHERLOCK_HOLMES |> Int]
  # Move a character
  move_character!(g, SHERLOCK_HOLMES, shpos .+ TR)
  assert_state_coherence(g)
  # Swap two characters
  swap_characters(g, WILLIAM_GULL, MISS_STEALTHY)
  assert_state_coherence(g)
  # Move numbered lamp L3
  posl3 = g.numbered_lamp_pos[3]
  move_lamp(g, posl3, posl3 .+ TR .+ TR .+ BR)
  assert_state_coherence(g)
  # Move an anonymous lamp
  move_lamp(g, g.char_pos[INSPECTOR_LESTRADE |> Int] .+ BR, posl3)
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
##### Visibility
#####

function make_neighborhood_visible!(V, pos)
  for dir in DIRECTIONS
    npos = pos .+ dir
    if valid_pos(INITIAL_BOARD, npos)
      V[pos...] = true
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

#####
##### Compute Available Moves
#####

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

#####
##### Export to JSON
#####

import JSON

struct InterfaceGameRepresentation
  g :: Game
end

function lower_character_dict(v)
  Dict([string(c) => v[Int(c)] for c in CHARACTERS])
end

function JSON.lower(r::InterfaceGameRepresentation)
  return Dict(
    "status" => r.g.status,
    "board" => r.g.board,
    "turn" => r.g.turn,
    "remchars" => r.g.remchars,
    "prev_chars" => r.g.prevchars,
    "selected" => r.g.selected,
    "used_power" => r.g.used_power,
    "used_move" => r.g.used_move,
    "wldir" => r.g.wldir,
    "jack" => r.g.jack,
    "shcards" => r.g.shcards,
    "cstatus" => lower_character_dict(r.g.cstatus),
    "visible" => lower_character_dict(r.g.visible)),
    "visibility_mask" => visibility_mask(r.g)
end

#####
##### Main
#####

test_moves()
test_reachability()
open("game.json", "w") do file
  repr = InterfaceGameRepresentation(Game())
  JSON.print(file, repr, 2)
end
