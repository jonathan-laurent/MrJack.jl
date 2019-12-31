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
##### Detectives knowledge
#####

"""
    CharacterStatus

Detectives knowledge about a character.
  - `UNKNOWN`: the detectives have no information
  - `GUILTY`: the detectives know that the character is guilty and are
     therefore make an accusation.
  - `INNOCENT_CK`: it is common knowledge that the character is innocent.
  - `INNOCENT_HI`: the detectives know that the character is innocent but
     Jack does not know that the detective know.
"""
@enum CharacterStatus UNKNOWN GUILTY INNOCENT_CK INNOCENT_HI

#####
##### Game State
#####

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

#####
##### Simple utilities
#####

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

#####
##### Cache management and state coherence
#####

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