import 'package:celestial_tripeaks/tripeaks_engine.dart';
import 'package:celestial_tripeaks/tripeaks_multiplayer.dart';
import 'package:test/test.dart';

void main() {
  group('Room foundation', () {
    RoomConfig buildConfig({
      int minMembers = 2,
      int maxMembers = 3,
    }) {
      return RoomConfig(
        roomId: 'room-1',
        matchMode: MatchMode.realtime,
        minMembers: minMembers,
        maxMembers: maxMembers,
        dealPolicyConfig: const DealPolicyConfig(mode: DealPolicyMode.random),
      );
    }

    test('first joined member becomes host', () {
      final room = RoomState.newRoom(config: buildConfig());
      final joined = tryReduceRoom(
        room,
        const JoinRoomEvent(memberId: 'p1'),
      );

      expect(joined.isSuccess, isTrue);
      expect(joined.state.hostMemberId, 'p1');
      expect(joined.state.members.single.joinOrder, 1);
    });

    test('duplicate joined member is rejected', () {
      var room = RoomState.newRoom(config: buildConfig());
      room = tryReduceRoom(room, const JoinRoomEvent(memberId: 'p1')).state;

      final duplicate = tryReduceRoom(
        room,
        const JoinRoomEvent(memberId: 'p1'),
      );

      expect(duplicate.isSuccess, isFalse);
      expect(
        duplicate.failure?.code,
        RoomReduceFailureCode.memberAlreadyJoined,
      );
    });

    test('host transfers deterministically by join order after leave', () {
      var room = RoomState.newRoom(config: buildConfig());
      room = tryReduceRoom(room, const JoinRoomEvent(memberId: 'p1')).state;
      room = tryReduceRoom(room, const JoinRoomEvent(memberId: 'p2')).state;
      room = tryReduceRoom(room, const JoinRoomEvent(memberId: 'p3')).state;

      final left = tryReduceRoom(
        room,
        const LeaveRoomEvent(memberId: 'p1'),
      );

      expect(left.isSuccess, isTrue);
      expect(left.state.hostMemberId, 'p2');
    });

    test('room closes when last joined member leaves', () {
      var room = RoomState.newRoom(config: buildConfig(minMembers: 1));
      room = tryReduceRoom(room, const JoinRoomEvent(memberId: 'p1')).state;

      final left = tryReduceRoom(
        room,
        const LeaveRoomEvent(memberId: 'p1'),
      );

      expect(left.isSuccess, isTrue);
      expect(left.state.roomStatus, RoomStatus.closed);
      expect(left.state.hostMemberId, isNull);
    });

    test('only deterministic host may bootstrap a match', () {
      var room = RoomState.newRoom(config: buildConfig());
      room = tryReduceRoom(room, const JoinRoomEvent(memberId: 'p1')).state;
      room = tryReduceRoom(room, const JoinRoomEvent(memberId: 'p2')).state;

      final denied = tryReduceRoom(
        room,
        const StartRoomMatchEvent(
          requestedByMemberId: 'p2',
          matchId: 'match-1',
          matchSeed: 77,
        ),
      );

      expect(denied.isSuccess, isFalse);
      expect(denied.failure?.code, RoomReduceFailureCode.hostRequired);
    });

    test('start validation enforces min members and emits canonical bootstrap',
        () {
      var room = RoomState.newRoom(config: buildConfig(minMembers: 2));
      room = tryReduceRoom(room, const JoinRoomEvent(memberId: 'p1')).state;

      final tooSmall = tryReduceRoom(
        room,
        const StartRoomMatchEvent(
          requestedByMemberId: 'p1',
          matchId: 'match-1',
          matchSeed: 77,
        ),
      );
      expect(tooSmall.isSuccess, isFalse);
      expect(
        tooSmall.failure?.code,
        RoomReduceFailureCode.invalidStartMembers,
      );

      room = tryReduceRoom(room, const JoinRoomEvent(memberId: 'p2')).state;
      final started = tryReduceRoom(
        room,
        const StartRoomMatchEvent(
          requestedByMemberId: 'p1',
          matchId: 'match-1',
          matchSeed: 77,
        ),
      );

      expect(started.isSuccess, isTrue);
      expect(started.bootstrap, isNotNull);
      expect(started.state.roomStatus, RoomStatus.matchInProgress);
      expect(started.state.activeMatchId, 'match-1');
      expect(
        started.bootstrap!.matchState.players.map((p) => p.playerId).toList(),
        equals(const <String>['p1', 'p2']),
      );
      expect(started.bootstrap!.matchConfig.maxPlayers, 2);
      expect(
        started.bootstrap!.matchState.authoritativeSequence,
        0,
      );
    });

    test('same room state and start payload yields identical bootstrap', () {
      final initial = replayRoomEvents(
        RoomState.newRoom(config: buildConfig()),
        const <RoomEvent>[
          JoinRoomEvent(memberId: 'p1'),
          JoinRoomEvent(memberId: 'p2'),
        ],
      );

      final a = tryReduceRoom(
        initial,
        const StartRoomMatchEvent(
          requestedByMemberId: 'p1',
          matchId: 'match-1',
          matchSeed: 77,
        ),
      );
      final b = tryReduceRoom(
        initial,
        const StartRoomMatchEvent(
          requestedByMemberId: 'p1',
          matchId: 'match-1',
          matchSeed: 77,
        ),
      );

      expect(a.bootstrap!.toMap(), equals(b.bootstrap!.toMap()));
      expect(a.state.toMap(), equals(b.state.toMap()));
    });

    test('sequential rematch requires completion before next start', () {
      var room = replayRoomEvents(
        RoomState.newRoom(config: buildConfig()),
        const <RoomEvent>[
          JoinRoomEvent(memberId: 'p1'),
          JoinRoomEvent(memberId: 'p2'),
        ],
      );

      final first = tryReduceRoom(
        room,
        const StartRoomMatchEvent(
          requestedByMemberId: 'p1',
          matchId: 'match-1',
          matchSeed: 77,
        ),
      );
      expect(first.isSuccess, isTrue);

      final deniedSecond = tryReduceRoom(
        first.state,
        const StartRoomMatchEvent(
          requestedByMemberId: 'p1',
          matchId: 'match-2',
          matchSeed: 99,
        ),
      );
      expect(deniedSecond.isSuccess, isFalse);
      expect(
        deniedSecond.failure?.code,
        RoomReduceFailureCode.matchAlreadyInProgress,
      );

      final reopened = tryReduceRoom(
        first.state,
        const CompleteRoomMatchEvent(matchId: 'match-1'),
      );
      expect(reopened.isSuccess, isTrue);
      expect(reopened.state.roomStatus, RoomStatus.open);

      final second = tryReduceRoom(
        reopened.state,
        const StartRoomMatchEvent(
          requestedByMemberId: 'p1',
          matchId: 'match-2',
          matchSeed: 99,
        ),
      );
      expect(second.isSuccess, isTrue);
      expect(second.bootstrap!.matchOrdinal, 2);
      expect(second.state.activeMatchId, 'match-2');
    });
  });
}
