#####
##### Value Function
#####

# Where do we evaluate the value function?
# Easier to compare equal things
# Fixed depth?

# About to select character OR
# How many turns?
# - Never beyond redistribution

# Value: someone is about to play

# Use number of innocented people
# Sherlock cards
# Winning status
# Number of available exits
# Number of lights near exits

# Can escape? provided as a shortcut

# Value from Jack's perspective.

function jack_found(g::Game)
  return GUILTY ∈ g.cstatus # This is cheating
end

# From what Jack knows
function num_possibly_guilty_for_detectives(g)
  return count(enumerate(g.cstatus)) do (i, s)
    Character(i) != g.jack && (s == UNKNOWN || s == INNOCENT_HI)
  end + 1
end

# Number of Sherlock cards drawn
#

# - 1 * Possibly guilty - 1 * sherlock cards
#

function value(g::Game)
  if game_terminated(g)
    return g.status == JACK_CAPTURED ? -Inf : Inf
  else
    curp = current_player(g)
    n = num_possibly_innocent_for_detectives(g)



  end
end
