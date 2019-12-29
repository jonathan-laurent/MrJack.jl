#####
##### Tile Definition
#####

# Characters
const Character = UInt8
const SHERLOCK_HOLMES = 0x1
const JEREMY_BERT = 0x2
const WILLIAM_GULL = 0x3
const JOHN_WATSON = 0x4
const INSPECTOR_LESTRADE = 0x5
const MISS_STEALTHY = 0x6
const JOHN_SMITH = 0x7
const SERGENT_GOODLEY = 0x8
const CHARACTERS = Vector{Character}(1:8)

const TileType = UInt8
const INVALID = 0x0 # see board encoding
const OUT_OF_BOUNDS = 0x1
const HOUSE = 0x2
const FREE = 0x3
const WELL = 0x4
const LAMP = 0x5
const EXIT = 0x6

# Representation fits in 4 bytes
struct Tile
  type :: TileType
  status :: Bool  # true/false <-> on/off <-> free/cops (default: false)
  lampid :: UInt8  # 1, 2, 3, 4, 0 (none)
  character :: Character
end

Tile(type, status=false) = Tile(type, status, 0x0, 0x0)

#####
##### Board Definition
#####

"""
The hexagonal tiling of the game board is encoded as the set of
black squares of a checkerboard. More precisely, it is encoded as
a 17×13 matrix whose about half of the squares have tile type `INVALID`.

A position is represented as a `(X, Y)` coordinates pair:
  - X coordinate increase when going down
  - Y coordinate increases when going right

"""
const Board = Array{Tile, 2}

"""
To access the neighbor of a tile, just add a direction vector to its position.
The six following directions are defined:

    D1
D6      D2
    ##
D5      D3
    D4
"""
const Direction = Tuple{Int, Int}
const DIRECTIONS =
  Direction[(-2, 0), (-1, 1), (1, 1), (2, 0), (1, -1), (-1, -1)]


#####
##### Initial Board
#####

"""
To describe the initial board, we use the following ASCII representation.
Each tile is represented by a two characters.

  - `..`: a free tile
  - `**`: a house tile
  - `##`: a position that is out of the board
  - `E+`: a free exit
  - `E-`: an exit guarded by a cop
  - `W+`: an open well
  - `W-`: a closed well
  - `L+`: an anonymous, lit lamp
  - `L-`: an anonymous, unlit lamp
  - `L#`: a lit lamp with number `#` from 1 to 4

# Character Initial positions:

  - IL: Inspector Lestrade
  - SG: Sergent Goodley
  - JW: John Watson
  - WG: Sir William Gull
  - MS: Miss Stealthy
  - JB: Jeremy Bert
  - SH: Sherlock Holmes
  - JS: John Smith
"""
const BOARD_STR =
"""
    E+      ##      W+      ##      ##      E-
##      ##      WG      ..      ##      ##      ##
    ..      ##      L-      ..      ##      W-
##      L3      ..      ..      ..      ..      ..
    W+      ..      **      **      ..      L2
..      ..      ..      JS      ..      ..      ..
    **      **      ..      L1      **      ..
..      **      ..      ..      JB      W+      SG
    **      ..      **      **      ..      **
MS      W+      IL      W+      ..      **      ..
    ..      **      L+      ..      **      **
..      ..      ..      SH      ..      ..      ..
    L1      ..      **      **      ..      W+
..      ..      ..      ..      ..      L4      ##
    W-      ##      ..      L-      **      ..
##      ##      ##      ..      JW      ##      ##
    E-      ##      ##      W+      ##      E+
"""

"""
Turn the raw ASCII representation of the board into a 2D matrix of 2-grams.
"""
function process_board_str(board::String) :: Array{String, 2}
  # Vector of lines (strings)
  lines = split(BOARD_STR, "\n")[1:end-1]
  # Each line is partitioned in a sequence of 2-grams
  lines = map(lines) do line
    grouped = Iterators.partition(line, 2) |> collect
    map(join, grouped)
  end
  # We only keep 2-grams at odd positions to eliminate spaces
  # Also, we add spaces to ensure that all lines have equal length
  for i in eachindex(lines)
    lines[i] = lines[i][1:2:end]
    if i % 2 == 1
      push!(lines[i], "  ")
    end
  end
  # Convert everything into a 2d array of characters (dims: ny×nx)
  nx = length(lines)
  ny = length(lines[1])
  return [lines[x][y] for x in 1:nx, y in 1:ny]
end

const BOARD_STR_MATRIX = process_board_str(BOARD_STR)

const CHARACTER_INITIALS = Dict(
  "SH" => SHERLOCK_HOLMES,
  "JB" => JEREMY_BERT,
  "WG" => WILLIAM_GULL,
  "JW" => JOHN_WATSON,
  "IL" => INSPECTOR_LESTRADE,
  "MS" => MISS_STEALTHY,
  "JS" => JOHN_SMITH,
  "SG" => SERGENT_GOODLEY)

function parse_init_tile(s)
  @assert length(s) == 2
  if haskey(CHARACTER_INITIALS, s)
    return Tile(FREE, false, 0, CHARACTER_INITIALS[s])
  elseif s == "  "
    return Tile(INVALID)
  elseif s == "##"
    return Tile(OUT_OF_BOUNDS)
  elseif s == "**"
    return Tile(HOUSE)
  elseif s == ".."
    return Tile(FREE)
  elseif s[1] == 'L'
    if s[2] ∈ ['+', '-']
      return Tile(LAMP, s[2] == '+')
    else
      n = parse(UInt8, s[2])
      @assert 1 <= n <= 4
      return Tile(LAMP, false, n, 0x0)
    end
  elseif s[1] == 'W'
    @assert s[2] ∈ ['+', '-']
    return Tile(WELL, s[2] == '+')
  elseif s[1] == 'E'
    @assert s[2] ∈ ['+', '-']
    return Tile(EXIT, s[2] == '+')
  else
    @assert false "Invalid tile 2-gram: $s"
  end
end

"""
The initial game board
"""
const INITIAL_BOARD = map(parse_init_tile, BOARD_STR_MATRIX)
