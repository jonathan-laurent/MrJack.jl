import JSON
using MrJack

CharD = Dict([ (string(x),x) for x in instances(Character)])

function main_loop()
    g = Game()
    history = []

    function char_at_pos(arr)
        return g.board[arr...].character
    end
    function activated_at_pos(arr)
        return g.board[arr...].activated
    end
    function exit_at_pos(arr)
        return g.board[arr...].type == MrJack.EXIT
    end
    function arr_to_tuple(arr)
        return tuple(arr...)
    end
    function moveAction(arr)
        if char_at_pos(arr) != MrJack.NO_CHARACTER
            return Accusation(char_at_pos(arr))
        elseif exit_at_pos(arr)
            return Escape(arr_to_tuple(arr))
        else
            return MoveCharacter(arr_to_tuple(arr))
        end
    end

    cmd = readline()
    while !isempty(cmd)
        s = split(cmd)
        if s[1] == "state"
            JSON.print(stdout, InterfaceGameRepresentation(g), 2)
        elseif s[1] == "back"
            if length(history) > 0
                g = pop!(history)
            end
            JSON.print(JSON.stdout, Dict("status" => 0), 2)
        elseif s[1] == "play" && length(s) >= 2
            try
                action = nothing
                if s[2] == "chance" && length(s) >= 3
                    args = JSON.parse(join(s[3:end], " "))
                    if g.status == PICKING_JACK && length(args) == 1
                        action = SelectJack(CharD[args[1]])
                    elseif g.status == PICKING_PLAYABLE_CHARACTERS && length(args) == 4
                        action = SelectPlayable(Set([CharD[arg] for arg in args]))
                    elseif g.status == PICKING_SHERLOCK_CARD && length(args) == 1
                        action = SelectSherlockCard(CharD[args[1]])
                    end
                elseif s[2] == "ai" && length(s) == 2
                    # TODO
                elseif s[2] == "user" && length(s) >= 4
                    args = JSON.parse(join(s[4:end], " "))
                    if s[3] == "choose" && length(args) == 1
                        action = SelectCharacter(CharD[args[1]])
                    elseif s[3] == "move"
                        action = moveAction(args["end"])
                    elseif s[3] == "power" && g.selected == SHERLOCK_HOLMES && length(args) == 0
                        action = AskSherlock()
                    elseif s[3] == "power" && length(args) >= 1
                        if g.selected == JEREMY_BERT
                            if activated_at_pos(args[1]["start"])
                                action = MoveLid(arr_to_tuple(args[1]["end"]), arr_to_tuple(args[1]["start"]))
                            else
                                action = MoveLid(arr_to_tuple(args[1]["start"]), arr_to_tuple(args[1]["end"]))
                            end
                        elseif g.selected == WILLIAM_GULL
                            character = char_at_pos(args[1]["end"])
                            if character == WILLIAM_GULL
                                character = char_at_pos(args[1]["start"])
                            end
                            if character !== nothing
                                action = SwapWilliamGull(character)
                            end
                        elseif g.selected == JOHN_WATSON && length(args) == 1
                            action = ReorientWatsonLight(arr_to_tuple(args[1]["end"]))
                        elseif g.selected == INSPECTOR_LESTRADE
                            if activated_at_pos(args[1]["start"])
                                action = MoveCops(arr_to_tuple(args[1]["end"]), arr_to_tuple(args[1]["start"]))
                            else
                                action = MoveCops(arr_to_tuple(args[1]["start"]), arr_to_tuple(args[1]["end"]))
                            end
                        elseif g.selected == MISS_STEALTHY && length(args) == 1
                            action = moveAction(args[1]["end"])
                        elseif g.selected == JOHN_SMITH
                            if activated_at_pos(args[1]["start"])
                                action = MoveLamp(arr_to_tuple(args[1]["start"]), arr_to_tuple(args[1]["end"]))
                            else
                                action = MoveLamp(arr_to_tuple(args[1]["end"]), arr_to_tuple(args[1]["start"]))
                            end
                        elseif g.selected == SERGENT_GOODLEY
                            action = UseWhistle([ (char_at_pos(arg["start"]), arr_to_tuple(arg["end"])) for arg in args ])
                        end
                    end
                end
                
                if action !== nothing && valid_action(g, action)
                    push!(history, deepcopy(g))
                    play!(g, action)
                    if valid_action(g,UnselectCharacter())
                        play!(g,UnselectCharacter())
                    end
                    if valid_action(g,FinishTurn())
                        play!(g,FinishTurn())
                    end
                    JSON.print(JSON.stdout, Dict("status" => 0), 2)
                else
                    JSON.print(JSON.stdout, Dict("status" => 1), 2)
                end
            catch e
                msg = sprint(showerror, e, catch_backtrace())
                JSON.print(JSON.stdout, Dict("status" => 2, "message" => msg), 2)
            end
        end
        flush(stdout)
        cmd = readline()
    end
end

main_loop()
