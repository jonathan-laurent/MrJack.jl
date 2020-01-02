using Test
using MrJack

@testset "Testing micro moves" begin
  g = Game()
  MrJack.assert_state_coherence(g)
  shpos = g.char_pos[SHERLOCK_HOLMES |> Int]
  # Move a character
  MrJack.move_character!(g, SHERLOCK_HOLMES, shpos .+ TR)
  MrJack.assert_state_coherence(g)
  # Swap two characters
  MrJack.swap_characters!(g, WILLIAM_GULL, MISS_STEALTHY)
  MrJack.assert_state_coherence(g)
  # Move numbered lamp L3
  posl3 = g.numbered_lamp_pos[3]
  MrJack.move_lamp!(g, posl3, posl3 .+ TR .+ TR .+ BR)
  MrJack.assert_state_coherence(g)
  # Move an anonymous lamp
  MrJack.move_lamp!(g, g.char_pos[INSPECTOR_LESTRADE |> Int] .+ BR, posl3)
  MrJack.assert_state_coherence(g)
  # Move a lid
  MrJack.move_lid!(g, g.numbered_lamp_pos[1] .+ BB, g.numbered_lamp_pos[4] .+ TR)
  MrJack.assert_state_coherence(g)
  # Switch L1 off
  MrJack.switch_off_numbered_lamp!(g, 1)
  g.turn = 2
  MrJack.assert_state_coherence(g)
  @test true
  # Testing multiple moves
  g = Game()
  MrJack.move_character!(g, JEREMY_BERT, shpos .+ TR)
  MrJack.assert_state_coherence(g)
  MrJack.move_characters!(g, [
    (JEREMY_BERT, shpos .+ TR .+ TR),
    (SHERLOCK_HOLMES, shpos .+ TR)])
  @test true
end

@testset "Testing reachability" begin
  g = Game()
  R = MrJack.reachable_positions(
    g.char_pos[SERGENT_GOODLEY |> Int], 3, g.active_wells)
  @test count(R) == 17
end

@testset "Simulating a simple game" begin
  g = Game()
  @noinline function do!(a)
    @test valid_action(g, a)
    play!(g, a)
    MrJack.assert_state_coherence(g)
  end
  @noinline function cant(a)
    @test !valid_action(g, a)
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

@testset "Testing Sgt. Goodley and Miss Stealthy" begin
  g = Game()
  @noinline function do!(a)
    @test valid_action(g, a)
    play!(g, a)
    MrJack.assert_state_coherence(g)
  end
  @noinline function cant(a)
    @test !valid_action(g, a)
  end
  do!(SelectJack(SHERLOCK_HOLMES))
  playable = Set([SERGENT_GOODLEY, MISS_STEALTHY, JEREMY_BERT, JOHN_SMITH])
  do!(SelectPlayable(playable))
  # Tests with Goodley's whistle
  do!(SelectCharacter(SERGENT_GOODLEY))
  shpos = g.char_pos[Int(SHERLOCK_HOLMES)]
  cant(UseWhistle([(SHERLOCK_HOLMES, shpos .+ BB)])) # Get further from SG
  cant(UseWhistle([(SHERLOCK_HOLMES, shpos .+ TR .+ TR .+ TR .+ TR)]))
  cant(UseWhistle([(SHERLOCK_HOLMES, shpos)]))
  cant(UseWhistle([ # Two destinations cannot be the same
    (SHERLOCK_HOLMES, shpos .+ 2 .* TR),
    (JEREMY_BERT, shpos .+ 2 .* TR)]))
  cant(UseWhistle([ # Four moves needed
    (SHERLOCK_HOLMES, shpos .+ 2 .* TR),
    (JEREMY_BERT, shpos .+ 4 .* TR)]))
  do!(UseWhistle([
    (SHERLOCK_HOLMES, shpos .+ 2 .* TR),
    (JEREMY_BERT, shpos .+ 3 .* TR)]))
  do!(MoveCharacter(g.char_pos[Int(SERGENT_GOODLEY)] .+ TT))
  do!(UnselectCharacter())
  # Testing Miss Stealthy
  do!(SelectCharacter(MISS_STEALTHY))
  cant(UnselectCharacter())
  cant(MoveCharacter(g.numbered_lamp_pos[2] .+ TR)) # Too far
  # Cannot form a move request that ends up on a house:
  @test_throws AssertionError MoveCharacter(g.numbered_lamp_pos[3] .+ 2 .* BB)
  do!(MoveCharacter(g.numbered_lamp_pos[3] .+ 2 .* BR))
  #do!(MoveCharacter(g.numbered_lamp_pos[3] .+ BB))
  do!(UnselectCharacter())
end

@testset "Adjacency and distance matrices" begin
  A = MrJack.adjacency_matrix()
  @test A == permutedims(A, [3, 4, 1, 2]) # Tha adjacency matrix is symmetric
  n = count(MrJack.STREET_TILES)
  d = sum(Int.(A)) / n # Average degree
  @test 2 <= d <= 3
  D = MrJack.distances_matrix()
  @test count(==(0x00), D) == 0
end
