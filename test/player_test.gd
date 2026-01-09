extends GdUnitTestSuite

## Tests for Player class to prevent regressions

var player_scene: PackedScene = preload("res://scenes/player.tscn")


func test_pickup_sound_deduplication_same_frame() -> void:
	# Test that multiple pickup sounds on the same frame only play once
	var player = auto_free(player_scene.instantiate())
	add_child(player)

	# Simulate being on frame 100
	var test_frame = 100
	player._last_pickup_sound_frame = test_frame - 1  # Previous frame

	# Count audio players before
	var audio_count_before = _count_audio_players()

	# First call should create a sound (we're on a new frame conceptually)
	# But since we can't mock Engine.get_process_frames(), we test the logic directly

	# If last frame matches current, sound should NOT play
	player._last_pickup_sound_frame = Engine.get_process_frames()
	player._play_pickup_sound()

	await get_tree().process_frame

	var audio_count_after = _count_audio_players()

	# Should not have created a new audio player since we're on same frame
	assert_that(audio_count_after).is_equal(audio_count_before)


func test_pickup_sound_plays_on_new_frame() -> void:
	# Test that pickup sound plays when on a different frame
	var player = auto_free(player_scene.instantiate())
	add_child(player)

	# Set last frame to -1 (never played)
	player._last_pickup_sound_frame = -1

	var audio_count_before = _count_audio_players()

	player._play_pickup_sound()

	await get_tree().process_frame

	var audio_count_after = _count_audio_players()

	# Should have created exactly one new audio player
	assert_that(audio_count_after).is_equal(audio_count_before + 1)


func test_last_pickup_sound_frame_updates() -> void:
	# Test that _last_pickup_sound_frame is updated after playing sound
	var player = auto_free(player_scene.instantiate())
	add_child(player)

	player._last_pickup_sound_frame = -1
	var frame_before = player._last_pickup_sound_frame

	player._play_pickup_sound()

	# Frame should have been updated to current frame
	assert_that(player._last_pickup_sound_frame).is_not_equal(frame_before)
	assert_that(player._last_pickup_sound_frame).is_equal(Engine.get_process_frames())


func _count_audio_players() -> int:
	var count = 0
	for child in get_tree().root.get_children():
		if child is AudioStreamPlayer:
			count += 1
	return count
