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
end

function branch_move(g)
  curp = current_player(g)
  @assert curp ∈ [JACK, DETECTIVES]
  char = g.selected
end

function branch_power(g)
  curp = current_player(g)
  @assert curp ∈ [JACK, DETECTIVES]
  char = g.selected
end
