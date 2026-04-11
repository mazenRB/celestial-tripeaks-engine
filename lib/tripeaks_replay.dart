/// Advanced public entrypoint for replay, save/load, and replay verification.
///
/// Import this library together with `tripeaks_engine.dart` when you need
/// deterministic replay logging, replay reconstruction, or save envelopes.
library;

export 'src/tripeaks_engine_internal.dart'
    show
        ReplaySession,
        TriPeaksReplay,
        ReplayActionKind,
        ReplayActionDto,
        ReplayFailureReason,
        ReplayEntry,
        ReplayRecordResult,
        recordAttempt,
        recordAction,
        replayToState,
        replayStep,
        replayFingerprint,
        SaveDecodeFailureCode,
        SaveDecodeFailure,
        SaveDecodeResult,
        DecodedRoundSave,
        DecodedSessionSave,
        DecodedReplaySave,
        encodeSaveRound,
        decodeSaveRound,
        encodeSaveSession,
        decodeSaveSession,
        encodeSaveReplay,
        decodeSaveReplay;
