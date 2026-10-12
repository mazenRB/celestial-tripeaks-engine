/// Optional replay verification boundary for multiplayer submissions.
///
/// This library does not provide networking or persistent storage. A host or
/// backend passes a player's recorded replay here to recompute its result.
library;

export 'src/multiplayer_authority.dart'
    show
        MatchSubmissionFailure,
        MatchSubmissionFailureCode,
        MatchSubmissionVerification,
        VerifiedMatchSubmission,
        verifyMatchSubmission;
