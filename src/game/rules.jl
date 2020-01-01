#####
##### Power modes
#####

@enum POWER_MODE begin
  BEFORE_OR_AFTER_MOVING
  INSTEAD_OF_MOVING
  AFTER_MOVING
end

const CHARACTER_POWER_MODE = Dict(
  SHERLOCK_HOLMES => AFTER_MOVING,
  JEREMY_BERT => BEFORE_OR_AFTER_MOVING,
  WILLIAM_GULL => INSTEAD_OF_MOVING,
  JOHN_WATSON => AFTER_MOVING,
  INSPECTOR_LESTRADE => BEFORE_OR_AFTER_MOVING,
  JOHN_SMITH => BEFORE_OR_AFTER_MOVING,
  SERGENT_GOODLEY => BEFORE_OR_AFTER_MOVING)

#####
##### Are actions valid?
#####

# Utilities

function valid_character_move(game, char, dst,
    escape=false, maxd=nothing, wells=game.active_wells)
  src = game.char_pos[Int(char)]
  ms = (char == MISS_STEALTHY)
  d = isnothing(maxd) ? (ms ? 4 : 3) : maxd
  R = reachable_positions(src, d, wells, all_tiles=ms)
  return R[dst...] && (!(get_type(game, dst) == EXIT) || escape)
end

function move_available(game)
  pm = CHARACTER_POWER_MODE[game.selected]
  return !game.used_move && !(game.used_power && pm == INSTEAD_OF_MOVING)
end

function power_available(game)
  pm = CHARACTER_POWER_MODE[game.selected]
  if pm == BEFORE_OR_AFTER_MOVING
    return !game.used_power
  elseif pm == AFTER_MOVING
    return !game.used_power && game.used_move
  else
    @assert pm == INSTEAD_OF_MOVING
    return !game.used_power && !game.used_move
  end
end

function done_with_selected_character(game)
  pm = CHARACTER_POWER_MODE[game.selected]
  if pm == INSTEAD_OF_MOVING
    return game.used_move || game.used_power
  else
    @assert pm ∈ [BEFORE_OR_AFTER_MOVING, AFTER_MOVING]
    return game.used_move && game.used_power
  end
end

function update_characters_status!(game)
  not_innocent = findall(game.cstatus) do st
    !(st == INNOCENT_CK || st == INNOCENT_HI)
  end
  @assert length(not_innocent) >= 1
  if length(not_innocent) == 1
    # Jack was found
    game.cstatus[not_innocent[1]] = GUILTY
  end
end

# Main function

function valid_action(game, action)
  st = game.status
  if endgame_status(st)
    return false
  elseif st == PICKING_JACK
    return isa(action, SelectJack)
  elseif st == PICKING_PLAYABLE_CHARACTERS
    return isa(action, SelectPlayable)
  elseif st == PICKING_SHERLOCK_CARD
    return isa(action, SelectSherlockCard) && action.innocent ∈ game.shcards
  elseif st == SELECTING_CHARACTER
    if isempty(game.remchars)
      return isa(action, FinishTurn)
    else
      return isa(action, SelectCharacter) && (action.character ∈ game.remchars)
    end
  elseif st == PLAYING_CHARACTER
    if done_with_selected_character(game)
      return isa(action, UnselectCharacter)
    else
      return valid_character_action(game, action)
    end
  else
    @assert false
    return false
  end
end

# Character actions

valid_character_action(game, action) = false

function valid_character_action(game, action::MoveCharacter)
  @assert game.status == PLAYING_CHARACTER
  move_available(game) || (return false)
  get_character(game, action.dst) == NO_CHARACTER || (return false)
  return valid_character_move(game, game.selected, action.dst)
end

function valid_character_action(game, action::Accusation)
  @assert game.status == PLAYING_CHARACTER
  if !(move_available(game) && current_player(game) == DETECTIVES)
    return false
  else
    dst = game.char_pos[action.accused]
    return valid_character_move(game, game.selected, dst)
  end
end

function valid_character_action(game, action::Escape)
  @assert game.status == PLAYING_CHARACTER
  if !(game.selected == game.jack && current_player(game) == JACK)
    return false
  else
    return action.dst ∉ game.cops_pos && !(game.visible[Int(game.jack)])
  end
end

function valid_character_action(game, action::PowerMove)
  @assert game.status == PLAYING_CHARACTER
  return power_available(game) && valid_power_move(game, action)
end

# Power moves

function valid_power_move(game, action::AskSherlock)
  return game.selected == SHERLOCK_HOLMES
end

function valid_power_move(game, action::ReorientWatsonLight)
  return game.selected == JOHN_WATSON
end

function valid_character_action(game, action::MoveLamp)
  game.selected == JOHN_SMITH || (return false)
  return get_activated(game, action.src) && !get_activated(game, action.dst)
end

function valid_character_action(game, action::MoveCops)
  game.selected == INSPECTOR_LESTRADE || (return false)
  return !get_activated(game, action.src) && get_activated(game, action.dst)
end

function valid_character_action(game, action::MoveLid)
  game.selected == JEREMY_BERT || (return false)
  return !get_activated(game, action.src) && get_activated(game, action.dst)
end

function valid_character_action(game, action::SwapWilliamGull)
  return game.selected == WILLIAM_GULL
end

function valid_character_action(game, action::UseWhistle)
  game.selected == SERGENT_GOODLEY || (return false)
  srcs = map(action.moves) do (c, dst)
    game.char_pos[Int(c)]
  end
  # There should not be multiple characters on a single tile
  for (c, dst) in action.moves
    if get_character(game, dst) != NO_CHARACTER && dst ∉ srcs
      return false
    end
  end
  # Characters should get closer to Sgt. Goodley
  goodley = game.char_pos[Int(SERGENT_GOODLEY)]
  for ((c, dst), src) in zip(action.moves, srcs)
    dsrc = DISTANCES_MATRIX[src..., goodley...]
    ddst = DISTANCES_MATRIX[dst..., goodley...]
    if ddst >= dsrc
      #@show (c, src, dst)
      #@show goodley
      #@show (c, dsrc, ddst)
      return false
    end
  end
  # The total number of tiles moved must be at most 3
  n = length(action.moves)
  if n == 1
    dss = [[3]]
  elseif n == 2
    dss = [[1, 2], [2, 1]]
  else
    @assert d == 3
    dss = [[1, 1, 1]]
  end
  return any(dss) do ds
    all(zip(action.moves, ds)) do ((c, dst), d)
      valid_character_move(game, c, dst, false, d, [])
    end
  end
end

#####
##### Execute actions
#####

# Utilities

function new_turn!(game)
  if game.turn >= 9
    game.status = TIMEOUT
  elseif game.turn % 2 == 1
    game.status = PICKING_PLAYABLE_CHARACTERS
  else
    remchars = Set{Character}([c for c in CHARACTERS if c ∉ game.prevchars])
    game.remchars = remchars
    @assert length(game.remchars) == 4
    game.prevchars = []
    game.status = SELECTING_CHARACTER
  end
end

# Chance actions

function play!(game, action::SelectJack)
  @assert game.jack == NO_CHARACTER
  @assert game.turn == 1
  game.jack = action.jack
  game.shcards = Set{Character}(filter(!=(action.jack), CHARACTERS))
  new_turn!(game) # to pick playable characters
end

function play!(game, action::SelectPlayable)
  game.remchars = copy(action.playable)
  game.prevchars = []
  game.status = SELECTING_CHARACTER
end

function play!(game, action::SelectSherlockCard)
  delete!(game.shcards, action.innocent)
  st = game.cstatus[Int(action.innocent)]
  @assert st != GUILTY
  if st == UNKNOWN
    game.cstatus[Int(action.innocent)] = INNOCENT_HI
    update_characters_status!(game)
  end
  game.status = SELECTING_CHARACTER
end

# Play actions

function play!(game, action::SelectCharacter)
  game.selected = action.character
  game.used_power = false
  game.used_move = false
  game.status = PLAYING_CHARACTER
end

function play!(game, action::UnselectCharacter)
  push!(game.prevchars, game.selected)
  delete!(game.remchars, game.selected)
  game.selected = NO_CHARACTER
  game.used_power = false
  game.used_move = false
  game.status = SELECTING_CHARACTER
end

function play!(game, action::FinishTurn)
  # Update visibility and detective's knowledge
  update_visible!(game)
  jv = game.visible[Int(game.jack)]
  for c in CHARACTERS
    v = game.visible[Int(c)]
    st = game.cstatus[Int(c)]
    if st ∈ [UNKNOWN, INNOCENT_HI] && v != jv
      game.cstatus[Int(c)] = INNOCENT_CK
    end
  end
  update_characters_status!(game)
  # Switch off a numbered lamp
  if 1 <= game.turn <= 4
    switch_off_numbered_lamp!(game, game.turn)
  end
  # Start a new turn
  game.turn += 1
  new_turn!(game)
end

function play!(game, action::MoveCharacter)
  move_character!(game, game.selected, action.dst)
  game.used_move = true
end

function play!(game, action::Accusation)
  if action.accused == game.jack
    game.status = JACK_CAPTURED
  else
    game.status = WRONG_ACCUSATION
  end
end

function play!(game, action::Escape)
  game.status = JACK_ESCAPED
end

# Power moves

function play!(game, action::PowerMove)
  play_power_move!(game, action)
  game.used_power = true
end

function play_power_move!(game, action::AskSherlock)
  game.status = PICKING_SHERLOCK_CARD
end

function play_power_move!(game, action::ReorientWatsonLight)
  game.wldir = action.dir
end

function play_power_move!(game, action::MoveLamp)
  move_lamp!(game, action.src, action.dst)
end

function play_power_move!(game, action::MoveCops)
  move_cops!(game, action.src, action.dst)
end

function play_power_move!(game, action::MoveLid)
  move_lid!(game, action.src, action.dst)
end

function play_power_move!(game, action::SwapWilliamGull)
  swap_characters!(game, WILLIAM_GULL, action.other)
end

function play_power_move!(game, action::UseWhistle)
  move_characters!(game, action.moves)
end

#####
##### Chance moves
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

#####
##### Initial State
#####

function Game()
  status = PICKING_JACK
  board = initial_board()
  turn = 1
  # This value of `remchar` won't be used. The only thing that matters is that
  # it has length 4 to avoid breaking the invariant
  remchars = pick_characters()
  prevchars = []
  selected = NO_CHARACTER
  used_power = false
  used_move = false
  wldir = BR
  jack = NO_CHARACTER
  shcards = Set() # Invalid until Jack is picked
  cstatus = [UNKNOWN for c in CHARACTERS]
  visible = falses(length(CHARACTERS)) # Dummy
  g = Game(
    status, board, turn, remchars, prevchars, selected, used_power, used_move,
    wldir, jack, shcards, cstatus, visible)
  update_visible!(g)
  return g
end
