extends GdUnitTestSuite
class_name TestTradeOfferGdUnit4

const TradeOffer = preload("res://scripts/core/trades/TradeOffer.gd")
const Pick = preload("res://scripts/core/trades/Pick.gd")

## Test creating empty TradeOffer
func test_create_empty_trade_offer() -> void:
	var offer := TradeOffer.new()

	assert_that(offer.send_player_ids).is_empty()
	assert_that(offer.send_picks).is_empty()
	assert_that(offer.receive_player_ids).is_empty()
	assert_that(offer.receive_picks).is_empty()

## Test adding players to send
func test_add_send_players() -> void:
	var offer := TradeOffer.new()
	offer.send_player_ids = ["P1", "P2", "P3"]

	assert_int(offer.send_player_ids.size()).is_equal(3)
	assert_string(offer.send_player_ids[0]).is_equal("P1")

## Test adding picks to send
func test_add_send_picks() -> void:
	var offer := TradeOffer.new()

	var pick1 := Pick.new()
	pick1.round = 1
	pick1.slot = 15

	var pick2 := Pick.new()
	pick2.round = 2
	pick2.slot = 20

	offer.send_picks = [pick1, pick2]

	assert_int(offer.send_picks.size()).is_equal(2)

## Test adding players to receive
func test_add_receive_players() -> void:
	var offer := TradeOffer.new()
	offer.receive_player_ids = ["P4", "P5"]

	assert_int(offer.receive_player_ids.size()).is_equal(2)
	assert_string(offer.receive_player_ids[0]).is_equal("P4")

## Test adding picks to receive
func test_add_receive_picks() -> void:
	var offer := TradeOffer.new()

	var pick := Pick.new()
	pick.round = 1
	pick.slot = 1

	offer.receive_picks = [pick]

	assert_int(offer.receive_picks.size()).is_equal(1)

## Test get_bundle for send side
func test_get_bundle_send() -> void:
	var offer := TradeOffer.new()
	offer.send_player_ids = ["P1", "P2"]

	var pick := Pick.new()
	pick.round = 1
	pick.slot = 10
	offer.send_picks = [pick]

	var bundle := offer.get_bundle(true)

	assert_that(bundle).contains_key("player_ids")
	assert_that(bundle).contains_key("picks")
	assert_int(bundle["player_ids"].size()).is_equal(2)
	assert_int(bundle["picks"].size()).is_equal(1)

## Test get_bundle for receive side
func test_get_bundle_receive() -> void:
	var offer := TradeOffer.new()
	offer.receive_player_ids = ["P3"]

	var pick := Pick.new()
	pick.round = 2
	pick.slot = 5
	offer.receive_picks = [pick]

	var bundle := offer.get_bundle(false)

	assert_that(bundle).contains_key("player_ids")
	assert_that(bundle).contains_key("picks")
	assert_int(bundle["player_ids"].size()).is_equal(1)
	assert_int(bundle["picks"].size()).is_equal(1)

## Test get_bundle returns copies
func test_get_bundle_returns_copy() -> void:
	var offer := TradeOffer.new()
	offer.send_player_ids = ["P1"]

	var bundle := offer.get_bundle(true)
	bundle["player_ids"].append("P2")

	# Original should be unchanged
	assert_int(offer.send_player_ids.size()).is_equal(1)

## Test simple player for player trade
func test_player_for_player_trade() -> void:
	var offer := TradeOffer.new()
	offer.send_player_ids = ["QB1"]
	offer.receive_player_ids = ["WR1"]

	assert_int(offer.send_player_ids.size()).is_equal(1)
	assert_int(offer.receive_player_ids.size()).is_equal(1)

## Test player for pick trade
func test_player_for_pick_trade() -> void:
	var offer := TradeOffer.new()
	offer.send_player_ids = ["RB1"]

	var pick := Pick.new()
	pick.round = 1
	pick.slot = 20
	offer.receive_picks = [pick]

	assert_int(offer.send_player_ids.size()).is_equal(1)
	assert_int(offer.receive_picks.size()).is_equal(1)

## Test pick for pick trade (trading up)
func test_pick_for_pick_trade() -> void:
	var offer := TradeOffer.new()

	# Send two late picks
	var pick1 := Pick.new()
	pick1.round = 2
	pick1.slot = 10

	var pick2 := Pick.new()
	pick2.round = 3
	pick2.slot = 10

	offer.send_picks = [pick1, pick2]

	# Receive one early pick
	var pick3 := Pick.new()
	pick3.round = 1
	pick3.slot = 25

	offer.receive_picks = [pick3]

	assert_int(offer.send_picks.size()).is_equal(2)
	assert_int(offer.receive_picks.size()).is_equal(1)

## Test complex multi-asset trade
func test_complex_trade() -> void:
	var offer := TradeOffer.new()

	# Send: 2 players and 1 pick
	offer.send_player_ids = ["QB1", "WR2"]

	var send_pick := Pick.new()
	send_pick.round = 3
	send_pick.slot = 5
	offer.send_picks = [send_pick]

	# Receive: 1 player and 2 picks
	offer.receive_player_ids = ["RB1"]

	var recv_pick1 := Pick.new()
	recv_pick1.round = 1
	recv_pick1.slot = 10

	var recv_pick2 := Pick.new()
	recv_pick2.round = 2
	recv_pick2.slot = 15

	offer.receive_picks = [recv_pick1, recv_pick2]

	assert_int(offer.send_player_ids.size()).is_equal(2)
	assert_int(offer.send_picks.size()).is_equal(1)
	assert_int(offer.receive_player_ids.size()).is_equal(1)
	assert_int(offer.receive_picks.size()).is_equal(2)

## Test trade with picks as dictionaries
func test_trade_with_pick_dicts() -> void:
	var offer := TradeOffer.new()

	var pick_dict := {
		"round": 1,
		"slot": 15,
		"year": 2025,
		"original_team_id": "TEAM_A",
		"current_owner_id": "TEAM_B"
	}

	offer.send_picks = [pick_dict]

	assert_int(offer.send_picks.size()).is_equal(1)

## Test empty bundles
func test_empty_bundles() -> void:
	var offer := TradeOffer.new()

	var send_bundle := offer.get_bundle(true)
	var recv_bundle := offer.get_bundle(false)

	assert_that(send_bundle["player_ids"]).is_empty()
	assert_that(send_bundle["picks"]).is_empty()
	assert_that(recv_bundle["player_ids"]).is_empty()
	assert_that(recv_bundle["picks"]).is_empty()

## Test one-sided trade (send only)
func test_one_sided_trade_send() -> void:
	var offer := TradeOffer.new()
	offer.send_player_ids = ["P1"]

	# Receive side empty
	assert_int(offer.send_player_ids.size()).is_equal(1)
	assert_that(offer.receive_player_ids).is_empty()

## Test one-sided trade (receive only)
func test_one_sided_trade_receive() -> void:
	var offer := TradeOffer.new()
	offer.receive_player_ids = ["P1"]

	# Send side empty
	assert_int(offer.receive_player_ids.size()).is_equal(1)
	assert_that(offer.send_player_ids).is_empty()

## Test future picks trade
func test_future_picks_trade() -> void:
	var offer := TradeOffer.new()

	var future_pick := Pick.new()
	future_pick.year = 2027
	future_pick.round = 1
	future_pick.slot = 1
	future_pick.original_team_id = "TEAM_A"
	future_pick.current_owner_id = "TEAM_B"

	offer.send_picks = [future_pick]

	assert_int(offer.send_picks.size()).is_equal(1)
	assert_int(offer.send_picks[0].year).is_equal(2027)

## Test multiple players same position
func test_multiple_players_same_position() -> void:
	var offer := TradeOffer.new()
	offer.send_player_ids = ["WR1", "WR2", "WR3"]

	assert_int(offer.send_player_ids.size()).is_equal(3)

## Test get_bundle with deep copy for picks
func test_get_bundle_deep_copy_picks() -> void:
	var offer := TradeOffer.new()

	var pick := Pick.new()
	pick.round = 1
	pick.slot = 1
	offer.send_picks = [pick]

	var bundle := offer.get_bundle(true)

	# Modify the returned pick
	if bundle["picks"][0] is Pick:
		bundle["picks"][0].round = 2

	# Original should be unchanged
	assert_int(offer.send_picks[0].round).is_equal(1)

## Test massive trade (many assets)
func test_massive_trade() -> void:
	var offer := TradeOffer.new()

	# Send 5 players and 3 picks
	offer.send_player_ids = ["P1", "P2", "P3", "P4", "P5"]

	for round in range(1, 4):
		var pick := Pick.new()
		pick.round = round
		pick.slot = 1
		offer.send_picks.append(pick)

	# Receive 2 players and 2 picks
	offer.receive_player_ids = ["P6", "P7"]

	for round in range(1, 3):
		var pick := Pick.new()
		pick.round = round
		pick.slot = 10
		offer.receive_picks.append(pick)

	assert_int(offer.send_player_ids.size()).is_equal(5)
	assert_int(offer.send_picks.size()).is_equal(3)
	assert_int(offer.receive_player_ids.size()).is_equal(2)
	assert_int(offer.receive_picks.size()).is_equal(2)
