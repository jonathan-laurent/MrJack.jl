module MrJack

export Game
export CHARACTERS, Character
export SHERLOCK_HOLMES, JEREMY_BERT, WILLIAM_GULL, JOHN_WATSON
export INSPECTOR_LESTRADE, MISS_STEALTHY, JOHN_SMITH, SERGENT_GOODLEY
export DIRECTIONS, TT, TR, BR, BB, BL, TL

export AbstractAction, ChanceAction, PowerMove
export SelectJack, SelectPlayable, SelectSherlockCard
export SelectCharacter, UnselectCharacter, FinishTurn, MoveCharacter
export Accusation, Escape
export AskSherlock, ReorientWatsonLight, MoveLamp, MoveCops, MoveLid
export SwapWilliamGull, UseWhistle

export play!, valid_action
export current_player, DETECTIVES, JACK
export CharacterStatus, UNKNOWN, GUILTY, INNOCENT_CK, INNOCENT_HI
export playable_characters

export GameStatus
export JACK_CAPTURED, JACK_ESCAPED, WRONG_ACCUSATION, TIMEOUT
export PICKING_JACK, PICKING_PLAYABLE_CHARACTERS, PICKING_SHERLOCK_CARD
export SELECTING_CHARACTER, PLAYING_CHARACTER

export InterfaceGameRepresentation

include("game/board.jl")
include("game/state.jl")
include("game/reachability.jl")
include("game/visibility.jl")
include("game/actions.jl")
include("game/rules.jl")

include("board_json.jl")

include("ai/value.jl")
include("ai/branch.jl")
include("ai/alphabeta.jl")
include("ai/ai.jl")

end
