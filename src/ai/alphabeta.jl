#####
##### Alpha-Beta Tree Search
#####

const DEBUG_MODE = false

function check_and_play(game, action)
    @assert !DEBUG_MODE || valid_action(game, action)
    return play!(copy(game))
end

function alphabeta(game, depth, α, β, maximizing)
    if depth == 0 || game_terminated(game)
        return value(game)
    end
    if maximizing
        v = -Inf
        for action in branch(game)
            child = check_and_play(copy(game))
            v = max(v, alphabeta(child, depth - 1, α, β, false))
            α = max(α, v)
            if α >= β
                break
            end
        end
    else
        v = +Inf
        for action in branch(game)
            child = check_and_play(copy(game))
            v = min(v, alphabeta(child, depth - 1, α, β, true))
            β = min(β, v)
            if α >= β
                break
            end
        end
    end
    return v
end