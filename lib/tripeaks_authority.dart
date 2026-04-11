/// Advanced public entrypoint for server-authority and runtime orchestration.
///
/// Import this library together with `tripeaks_engine.dart` and
/// `tripeaks_multiplayer.dart` when you need authoritative match validation,
/// persistence, reconnect handling, or runtime restore flows.
library;

export 'src/tripeaks_engine_internal.dart'
    show
        ServerRejectReason,
        ServerApplyStatus,
        ClientEvent,
        ServerEventRecord,
        ServerAuthorityState,
        ServerResult,
        ReconnectRequest,
        ReconnectFailureCode,
        ReconnectFailure,
        ReconnectResult,
        applyClientEvent,
        replayAcceptedServerEvents,
        handleReconnect,
        AuthorityRuntimeConfig,
        AuthorityStorePort,
        PersistedAuthorityEvent,
        PersistedAuthoritySnapshot,
        AuthorityApplyFailureCode,
        AuthorityApplyFailure,
        AuthorityRestoreFailureCode,
        AuthorityRestoreFailure,
        AuthorityRequestContext,
        AuthorityRuntimeState,
        AuthorityApplyResult,
        AuthorityRestoreResult,
        AuthorityRuntime,
        InMemoryAuthorityStore;
