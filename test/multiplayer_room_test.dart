import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:celestial_tripeaks/tripeaks_multiplayer.dart';
import 'package:test/test.dart';

void main() {
  group('multiplayer rooms', () {
    RoomConfig roomConfig({MatchMode mode = MatchMode.live}) => RoomConfig(
          roomId: 'room-1',
          hostPlayerId: 'p1',
          matchConfig: MatchConfig(
            matchMode: mode,
            matchId: 'template',
            matchSeed: 0,
            playerIds: const <String>['p1', 'p2'],
            ruleset: TriPeaksRuleset.threeRounds,
            roundTimerConfig: mode == MatchMode.live
                ? const RoundTimerConfig(
                    enabled: true,
                    durationsSecondsByRound: <int>[60, 50, 40],
                  )
                : const RoundTimerConfig(),
          ),
          minPlayers: 2,
          maxPlayers: mode == MatchMode.asynchronous ? 2 : 4,
        );

    test('host starts a shared-seed match for the joined fixed roster', () {
      var room = RoomState.newRoom(config: roomConfig());
      room = tryReduceRoom(room, const JoinRoomEvent(playerId: 'p2')).state;
      room = tryReduceRoom(room, const JoinRoomEvent(playerId: 'p3')).state;

      final started = tryReduceRoom(
        room,
        const StartRoomMatchEvent(
          requestedByPlayerId: 'p1',
          matchId: 'live-match',
          matchSeed: 998,
        ),
      );

      expect(started.isSuccess, isTrue);
      expect(started.state.status, RoomStatus.active);
      expect(started.state.activeMatch!.config.playerIds, <String>[
        'p1',
        'p2',
        'p3',
      ]);
      expect(started.state.activeMatch!.players, hasLength(3));
    });

    test('host transfers deterministically when leaving an open room', () {
      var room = RoomState.newRoom(config: roomConfig());
      room = tryReduceRoom(room, const JoinRoomEvent(playerId: 'p2')).state;
      room = tryReduceRoom(room, const JoinRoomEvent(playerId: 'p3')).state;

      final left = tryReduceRoom(
        room,
        const LeaveRoomEvent(playerId: 'p1'),
      );

      expect(left.isSuccess, isTrue);
      expect(left.state.hostPlayerId, 'p2');
    });

    test('async room cannot admit or start a third participant', () {
      var room = RoomState.newRoom(
        config: roomConfig(mode: MatchMode.asynchronous),
      );
      room = tryReduceRoom(room, const JoinRoomEvent(playerId: 'p2')).state;

      final third = tryReduceRoom(room, const JoinRoomEvent(playerId: 'p3'));
      expect(third.isSuccess, isFalse);
      expect(third.state.members, hasLength(2));
    });
  });
}
