#####
##### Branching Function
#####

function branch(g::Game) :: Vector{AbstractAction}
  st = g.status
  # Chance nodes
  if st == PICKING_JACK
    @warn "Branching on Jack's choice"
    return [SelectJack(c) for c in CHARACTERS]
  elseif st == PICKING_PLAYABLE_CHARACTERS
    return branch_playable(g)
  elseif st == PICKING_SHERLOCK_CARD
    return branch_shcard(g)
  elseif st == SELECTING_CHARACTER
    playable = playable_characters(g)
    return isempty(playable) ? [FinishTurn()] : branch_select(g, playable)
  elseif st == PLAYING_CHARACTER
    if done_with_selected_character(g)
      return [UnselectCharacter()]
    elseif CHARACTER_POWER_MODE[char] == INSTEAD_OF_MOVING
      return [branch_move(g) ; branch_power(g)]
    else
      return used_move(g) ? branch_power(g) : branch_move(g)
    end
  else
    @assert false; return []
  end
end

function branch_shcard(g)
  # TODO
  # what happens if we select a sherlock card that has already be selected?
  # do we really want to branch here
  return []
end

function branch_playable(g)
  d = 5
  choices = Set{Set{Character}}()
  while length(choices) <= d
    push!(choices, pick_characters())
  end
  return [SelectPlayable(choices) for c in choices]
end

function branch_select(g, playable)
  curp = current_player(g)
  @assert curp ∈ [JACK, DETECTIVES]
  preferences = [SERGENT_GOODLEY, WILLIAM_GULL, JOHN_SMITH, JOHN_WATSON,
    JEREMY_BERT, INSPECTOR_LESTRADE, MISS_STEALTHY, SHERLOCK_HOLMES]
  if curp == JACK || g.cstatus[g.jack] == GUILTY
      filter!((!=) g.jack, preferences)
      pushfirst!(preferences, g.jack)
  end
  preferences = [SelectCharacter(c) for c in preferences]
  return preferences
end

function branch_move(g)
  curp = current_player(g)
  @assert curp ∈ [JACK, DETECTIVES]
  char = g.selected
  # When Jack plays Jack or Detectives play somebody suspected to be Jack
  # (In this last case, take the negation)
  # Compute a score for all the possible destinations:
  #   +1 when 1-case away from a well
  #   +2 when on a well
  #   +1 when <= 3-cases away from an exit (activated or not)
  #   +2 when it breaks the dichotomy (only for stage 1)
  #   -2 when it improves the dichotomy (only for stage 1)
  #   +1 when invisible if the character is Jack
  # When Jack play somebody else or Detectives play somebody innocent
  # (In this last case, take the negation)
  #   +2 when it breaks the dichotomy (only for stage 1)
  #   -2 when it improves the dichotomy (only for stage 1)
  #   -1 per possibly guilty character reachable

  # Take the n actions with higher score
end

function branch_power(g)
  curp = current_player(g)
  @assert curp ∈ [JACK, DETECTIVES]
  char = g.selected

  if char == SHERLOCK_HOLMES
      return [AskSherlock()]

  elseif char == JEREMY_BERT
      

  elseif char == WILLIAM_GULL
  elseif char == JOHN_WATSON
  elseif char == INSPECTOR_LESTRADE
  elseif char == MISS_STEALTHY
  elseif char == JOHN_SMITH
  elseif char == SERGENT_GOODLEY
  end
end
