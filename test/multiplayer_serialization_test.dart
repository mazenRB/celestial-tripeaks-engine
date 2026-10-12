import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:celestial_tripeaks/tripeaks_multiplayer.dart';
import 'package:test/test.dart';

void main() {
  test('match config and state preserve versioned round-trip maps', () {
    const config = MatchConfig(
      matchMode: MatchMode.live,
      matchId: 'live-serial',
      matchSeed: 73,
      playerIds: <String>['p1', 'p2'],
      roundTimerConfig: RoundTimerConfig(
        enabled: true,
        durationsSecondsByRound: <int>[40, 30, 20],
      ),
    );
    final decodedConfig = MatchConfig.tryFromMap(config.toMap());
    expect(decodedConfig.isSuccess, isTrue);
    expect(decodedConfig.value!.toMap(), config.toMap());

    final state = MatchState.newMatch(config: config);
    final decodedState = MatchState.tryFromMap(state.toMap());
    expect(decodedState.isSuccess, isTrue);
    expect(decodedState.value!.toMap(), state.toMap());
    final unsupported = MatchState.tryFromMap(<String, dynamic>{
      ...state.toMap(),
      'schemaVersion': 2,
    });
    expect(unsupported.isSuccess, isFalse);
    expect(
      unsupported.error!.code,
      DecodeFailureCode.unsupportedSchemaVersion,
    );
  });

  test('match decoder rejects session and replay that disagree', () {
    const config = MatchConfig(
      matchMode: MatchMode.asynchronous,
      matchId: 'session-replay-integrity',
      matchSeed: 73,
      playerIds: <String>['p1', 'p2'],
      ruleset: TriPeaksRuleset.oneRound,
    );
    final initial = MatchState.newMatch(config: config);
    final progressed = tryReduceMatch(
      initial,
      const SubmitMatchActionEvent(
        playerId: 'p1',
        action: AbortRoundAction(),
      ),
    );
    expect(progressed.isSuccess, isTrue);

    final snapshot = progressed.state.toMap();
    final players = snapshot['players'] as List<dynamic>;
    final player = players.first as Map<String, dynamic>;
    player['replay'] = initial.players.first.replay.toMap();

    final decoded = MatchState.tryFromMap(snapshot);

    expect(decoded.isSuccess, isFalse);
  });

  test('match decoder rejects snapshots from a different shared seed', () {
    const config = MatchConfig(
      matchMode: MatchMode.asynchronous,
      matchId: 'shared-seed-integrity',
      matchSeed: 73,
      playerIds: <String>['p1', 'p2'],
      ruleset: TriPeaksRuleset.oneRound,
    );
    final expected = MatchState.newMatch(config: config);
    final otherSeed = MatchState.newMatch(
      config: config.copyWith(matchSeed: 74),
    );
    final snapshot = expected.toMap();
    snapshot['players'] =
        otherSeed.players.map((player) => player.toMap()).toList();

    final decoded = MatchState.tryFromMap(snapshot);

    expect(decoded.isSuccess, isFalse);
  });

  test('copyWith rejects player snapshots from a different match', () {
    const config = MatchConfig(
      matchMode: MatchMode.asynchronous,
      matchId: 'copy-integrity',
      matchSeed: 73,
      playerIds: <String>['p1', 'p2'],
      ruleset: TriPeaksRuleset.oneRound,
    );
    final match = MatchState.newMatch(config: config);
    final otherMatch = MatchState.newMatch(
      config: config.copyWith(matchSeed: 74),
    );

    expect(
      () => match.copyWith(players: otherMatch.players),
      throwsArgumentError,
    );
  });

  test('room config, active match, and events are serializable', () {
    const roomConfig = RoomConfig(
      roomId: 'room-serial',
      hostPlayerId: 'p1',
      matchConfig: MatchConfig(
        matchMode: MatchMode.asynchronous,
        matchId: 'template',
        matchSeed: 0,
        playerIds: <String>['p1', 'p2'],
        ruleset: TriPeaksRuleset.oneRound,
      ),
    );
    var room = RoomState.newRoom(config: roomConfig);
    room = tryReduceRoom(room, const JoinRoomEvent(playerId: 'p2')).state;
    room = tryReduceRoom(
      room,
      const StartRoomMatchEvent(
        requestedByPlayerId: 'p1',
        matchId: 'serial-match',
        matchSeed: 99,
      ),
    ).state;
    final decodedRoom = RoomState.tryFromMap(room.toMap());
    expect(decodedRoom.isSuccess, isTrue);
    expect(decodedRoom.value!.toMap(), room.toMap());

    const vote = VoteToSkipLiveIntermissionEvent(playerId: 'p2');
    final decodedVote = MatchEvent.tryFromMap(vote.toMap());
    expect(decodedVote.isSuccess, isTrue);
    expect(decodedVote.value!.toMap(), vote.toMap());

    const join = JoinRoomEvent(playerId: 'p3');
    final decodedJoin = RoomEvent.tryFromMap(join.toMap());
    expect(decodedJoin.isSuccess, isTrue);
    expect(decodedJoin.value!.toMap(), join.toMap());
  });

  test('ordered match and room events reproduce exact states', () {
    const config = MatchConfig(
      matchMode: MatchMode.asynchronous,
      matchId: 'replay-match',
      matchSeed: 12,
      playerIds: <String>['p1', 'p2'],
      ruleset: TriPeaksRuleset.oneRound,
    );
    final initialMatch = MatchState.newMatch(config: config);
    final matchEvents = <MatchEvent>[
      const SubmitMatchActionEvent(
        playerId: 'p1',
        action: AbortRoundAction(),
      ),
      const SubmitMatchActionEvent(
        playerId: 'p2',
        action: AbortRoundAction(),
      ),
    ];
    final finalMatch = replayMatchEvents(initialMatch, matchEvents);
    final decodedMatchEvents = matchEvents
        .map((event) => MatchEvent.tryFromMap(event.toMap()).value!)
        .toList();
    expect(
      replayMatchEvents(initialMatch, decodedMatchEvents).toMap(),
      finalMatch.toMap(),
    );

    const roomConfig = RoomConfig(
      roomId: 'replay-room',
      hostPlayerId: 'p1',
      matchConfig: config,
    );
    final initialRoom = RoomState.newRoom(config: roomConfig);
    const roomEvents = <RoomEvent>[
      JoinRoomEvent(playerId: 'p2'),
      StartRoomMatchEvent(
        requestedByPlayerId: 'p1',
        matchId: 'room-match',
        matchSeed: 777,
      ),
    ];
    final finalRoom = replayRoomEvents(initialRoom, roomEvents);
    final decodedRoomEvents = roomEvents
        .map((event) => RoomEvent.tryFromMap(event.toMap()).value!)
        .toList();
    expect(
      replayRoomEvents(initialRoom, decodedRoomEvents).toMap(),
      finalRoom.toMap(),
    );
  });
}
