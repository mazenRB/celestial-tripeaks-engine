/// Optional deterministic multiplayer match and live-room coordination APIs.
///
/// Import alongside `tripeaks_engine.dart` to use independent Async matches or
/// synchronized Live round progression.
library;

export 'src/multiplayer_config.dart' show MatchConfig, MatchMode;
export 'src/multiplayer_events.dart'
    show
        AdvanceAsyncDeadlineEvent,
        AdvanceLiveIntermissionEvent,
        MatchEvent,
        MatchReduceFailure,
        MatchReduceFailureCode,
        MatchReduceResult,
        SubmitMatchActionEvent,
        VoteToSkipLiveIntermissionEvent,
        WithdrawFromAsyncMatchEvent;
export 'src/multiplayer_reducer.dart'
    show reduceMatch, replayMatchEvents, tryReduceMatch;
export 'src/multiplayer_results.dart'
    show MatchResult, MatchStateResultData, PlayerMatchResult;
export 'src/multiplayer_player_state.dart' show MatchPlayerState;
export 'src/multiplayer_state.dart' show MatchPhase, MatchState;
export 'src/multiplayer_room.dart'
    show
        CompleteRoomMatchEvent,
        JoinRoomEvent,
        LeaveRoomEvent,
        RoomConfig,
        RoomEvent,
        RoomMemberState,
        RoomReduceFailure,
        RoomReduceFailureCode,
        RoomReduceResult,
        RoomState,
        RoomStatus,
        StartRoomMatchEvent,
        reduceRoom,
        replayRoomEvents,
        tryReduceRoom;
