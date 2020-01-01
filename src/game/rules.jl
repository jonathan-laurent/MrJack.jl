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

function valid_character_move(game, char, dst, escape=false, maxd=nothing)
  src = game.char_pos[Int(game.selected)]
  ms = (char == MISS_STEALTHY)
  d = isnothing(maxd) ? (ms ? 4 : 3) : maxd
  R = reachable_positions(src, d, game.active_wells, all_tiles=ms)
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
  return true # TODO
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
  return # TODO
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

#####
##### Test Rules
#####

function test_rules()
  g = Game()
  @noinline function do!(a)
    @assert valid_action(g, a)
    play!(g, a)
    assert_state_coherence(g)
  end
  @noinline function cant(a)
    @assert !valid_action(g, a)
  end
  # Simulate a short game
  do!(SelectJack(SHERLOCK_HOLMES))
  playable_1 = Set([WILLIAM_GULL, INSPECTOR_LESTRADE, JEREMY_BERT, JOHN_SMITH])
  do!(SelectPlayable(playable_1))
  @assert current_player(g) == DETECTIVES
  cant(SelectCharacter(SHERLOCK_HOLMES))
  do!(SelectCharacter(WILLIAM_GULL))
  do!(SwapWilliamGull(SERGENT_GOODLEY))
  cant(MoveCharacter(g.numbered_lamp_pos[3] .+ BR .+ TR))
  do!(UnselectCharacter())
  cant(FinishTurn())
  @assert current_player(g) == JACK
  cant(SelectCharacter(WILLIAM_GULL))
  do!(SelectCharacter(INSPECTOR_LESTRADE))
  exit1 = g.numbered_lamp_pos[1] .+ BB .+ BB
  exit4 = g.numbered_lamp_pos[4] .+ BR .+ BB
  do!(MoveCops(exit1, exit4))
  cant(FinishTurn())
  jspos = g.char_pos[Int(JOHN_SMITH)]
  cant(MoveCharacter(jspos .+ TT))
  do!(MoveCharacter(jspos .+ BL))
  cant(FinishTurn())
  do!(UnselectCharacter())
  @assert current_player(g) == JACK
  do!(SelectCharacter(JEREMY_BERT))
  jbpos = g.char_pos[Int(JEREMY_BERT)]
  do!(MoveCharacter(jbpos .+ BB))
  do!(MoveLid(exit1 .+ TT, exit4 .+ TT .+ TT))
  do!(UnselectCharacter())
  cant(FinishTurn())
  @assert current_player(g) == DETECTIVES
  do!(SelectCharacter(JOHN_SMITH))
  cant(MoveCharacter(jspos))
  do!(MoveCharacter(jspos .+ TT))
  jspos = g.char_pos[Int(JOHN_SMITH)]
  shpos = g.char_pos[Int(SHERLOCK_HOLMES)]
  do!(MoveLamp(shpos .+ TL, jspos .+ TL))
  do!(UnselectCharacter())
  do!(FinishTurn())
  @assert g.turn == 2
  @assert count(g.visible) == 2 # JS and SG
  @assert g.cstatus[Int(JOHN_SMITH)] == INNOCENT_CK
  @assert g.cstatus[Int(SERGENT_GOODLEY)] == INNOCENT_CK
  @assert g.cstatus[Int(SHERLOCK_HOLMES)] == UNKNOWN
  cant(SelectPlayable(playable_1))
  playable_2 = Set([c for c in CHARACTERS if c ∉ playable_1])
  @assert playable_characters(g) == playable_2
  @assert current_player(g) == JACK
  do!(SelectCharacter(SHERLOCK_HOLMES))
  do!(Escape(exit1))
  @assert g.status == JACK_ESCAPED
  cant(AskSherlock())
end
