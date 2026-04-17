/// Neutral public entrypoint for optional non-core TriPeaks helpers.
///
/// Import this library together with `tripeaks_engine.dart` when you want
/// deterministic completed-run summaries, run comparison helpers, or
/// aggregation helpers that operate on independent completed runs.
library;

export 'src/tripeaks_engine_internal.dart'
    show
        CompletedRunStatus,
        CompletedSessionResult,
        CompetitionTieBreakerPolicy,
        CompetitionRankingConfig,
        RunComparisonBreakdown,
        RankedRunResult,
        CompetitionComparisonResult,
        compareCompletedRuns,
        CompetitionScoreConfig,
        CompetitionScoreErrorCode,
        CompetitionScoreError,
        CompetitionScoreReduceResult,
        CompetitionScoreEvent,
        RunScoreRecorded,
        BonusApplied,
        PlacementAdjustmentApplied,
        CompetitionScoreState,
        reduceCompetitionScore,
        tryReduceCompetitionScore;
