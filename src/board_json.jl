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
    "visible" => lower_character_dict(r.g.visible),
    "visibility_mask" => visibility_mask(r.g))
end
