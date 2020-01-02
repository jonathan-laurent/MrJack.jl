
using MrJack

open("game.json", "w") do file
  repr = InterfaceGameRepresentation(Game())
  JSON.print(file, repr, 2)
end
