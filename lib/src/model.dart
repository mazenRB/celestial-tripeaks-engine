part of '../tripeaks_engine.dart';

/// The four standard suits in a card deck.
enum Suit {
  clubs,
  diamonds,
  hearts,
  spades,
}

/// The thirteen standard card ranks.
enum Rank {
  ace(1, 'A'),
  two(2, '2'),
  three(3, '3'),
  four(4, '4'),
  five(5, '5'),
  six(6, '6'),
  seven(7, '7'),
  eight(8, '8'),
  nine(9, '9'),
  ten(10, '10'),
  jack(11, 'J'),
  queen(12, 'Q'),
  king(13, 'K');

  const Rank(this.value, this.label);

  /// Numeric rank value from 1 (ace) to 13 (king).
  final int value;

  /// Short display label.
  final String label;

  /// Returns `true` when ranks are one apart.
  bool isAdjacentTo(Rank other) {
    final diff = (value - other.value).abs();
    return diff == 1;
  }
}

/// Card type discriminator used for deterministic serialization.
enum CardKind {
  normal,
  anchor,
  joker,
}

/// Immutable playing card.
final class Card {
  /// Creates a standard card from a [rank] and [suit].
  const Card(this._rank, this._suit) : kind = CardKind.normal;

  /// Creates a deterministic non-deck anchor card with [rank].
  const Card.anchor(Rank rank)
      : _rank = rank,
        _suit = null,
        kind = CardKind.anchor;

  /// Creates a joker/wildcard anchor card.
  const Card.joker()
      : _rank = null,
        _suit = null,
        kind = CardKind.joker;

  final Rank? _rank;
  final Suit? _suit;

  /// Card kind.
  final CardKind kind;

  /// Whether this card is a joker/wildcard.
  bool get isJoker => kind == CardKind.joker;

  /// Whether this card is a deterministic non-deck anchor.
  bool get isAnchor => kind == CardKind.anchor;

  /// The card rank.
  ///
  /// Only available for non-joker cards.
  Rank get rank {
    final value = _rank;
    if (value == null) {
      throw StateError('Joker cards do not have a rank.');
    }
    return value;
  }

  /// The card suit.
  ///
  /// Only available for normal deck cards.
  Suit get suit {
    final value = _suit;
    if (value == null) {
      throw StateError('Only normal deck cards have a suit.');
    }
    return value;
  }

  /// A full 52-card deck in deterministic suit/rank order.
  static List<Card> standardDeck() {
    final cards = <Card>[];
    for (final suit in Suit.values) {
      for (final rank in Rank.values) {
        cards.add(Card(rank, suit));
      }
    }
    return cards;
  }

  @override
  String toString() {
    if (isJoker) {
      return 'Joker';
    }
    if (isAnchor) {
      return 'Anchor(${rank.label})';
    }
    return '${rank.label} of $suit';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Card &&
        other.kind == kind &&
        other._rank == _rank &&
        other._suit == _suit;
  }

  @override
  int get hashCode => Object.hash(kind, _rank, _suit);

  /// Serializes card to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'card',
      'cardKind': kind.name,
      if (!isJoker) 'rank': rank.name,
      if (kind == CardKind.normal) 'suit': suit.name,
    };
  }

  /// Decodes card from map without throwing.
  static DecodeResult<Card> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'card') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final kindName = map['cardKind'];
    if (kindName == null) {
      final rankName = map['rank'];
      final suitName = map['suit'];
      if (rankName is! String || suitName is! String) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'Card rank and suit must be strings.',
          ),
        );
      }
      try {
        return DecodeResult.success(
          Card(
            Rank.values.byName(rankName),
            Suit.values.byName(suitName),
          ),
        );
      } on Object catch (error) {
        return DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'Invalid card payload: $error',
          ),
        );
      }
    }

    if (kindName is! String) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'cardKind must be a string when present.',
        ),
      );
    }
    try {
      final kind = CardKind.values.byName(kindName);
      if (kind == CardKind.joker) {
        return const DecodeResult.success(Card.joker());
      }
      if (kind == CardKind.anchor) {
        final rankName = map['rank'];
        if (rankName is! String) {
          return const DecodeResult.failure(
            DecodeFailure(
              code: DecodeFailureCode.invalidPayload,
              message: 'Anchor rank must be a string.',
            ),
          );
        }
        return DecodeResult.success(
          Card.anchor(Rank.values.byName(rankName)),
        );
      }
      final rankName = map['rank'];
      final suitName = map['suit'];
      if (rankName is! String || suitName is! String) {
        return const DecodeResult.failure(
          DecodeFailure(
            code: DecodeFailureCode.invalidPayload,
            message: 'Card rank and suit must be strings.',
          ),
        );
      }
      return DecodeResult.success(
        Card(
          Rank.values.byName(rankName),
          Suit.values.byName(suitName),
        ),
      );
    } on Object catch (error) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid card payload: $error',
        ),
      );
    }
  }
}

/// Result of inspecting currently available actions.
final class TriPeaksMoves {
  /// Creates a move snapshot.
  const TriPeaksMoves({
    required this.removableTableauIndices,
    required this.canDrawFromStock,
  });

  /// Indices of exposed cards that can be moved to waste.
  final List<int> removableTableauIndices;

  /// Whether drawing from stock is currently possible.
  final bool canDrawFromStock;
}

/// Immutable calendar date without timezone/time-of-day.
final class DateOnly {
  /// Creates a date from explicit [year], [month], and [day].
  const DateOnly(this.year, this.month, this.day)
      : assert(month >= 1 && month <= 12),
        assert(day >= 1 && day <= 31);

  /// Creates a date from a [DateTime] by taking only Y-M-D components.
  factory DateOnly.fromDateTime(DateTime dateTime) {
    return DateOnly(dateTime.year, dateTime.month, dateTime.day);
  }

  /// Gregorian calendar year.
  final int year;

  /// Gregorian month in range `1..12`.
  final int month;

  /// Day-of-month in range `1..31`.
  final int day;

  /// Returns ISO-like `YYYY-MM-DD`.
  String toIsoString() {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is DateOnly &&
        other.year == year &&
        other.month == month &&
        other.day == day;
  }

  @override
  int get hashCode => Object.hash(year, month, day);

  /// Serializes date to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'date_only',
      'year': year,
      'month': month,
      'day': day,
    };
  }

  /// Decodes date from map without throwing.
  static DecodeResult<DateOnly> tryFromMap(Map<String, dynamic> map) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'date_only') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final year = map['year'];
    final month = map['month'];
    final day = map['day'];
    if (year is! int || month is! int || day is! int) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'DateOnly year/month/day must be ints.',
        ),
      );
    }
    return DecodeResult.success(DateOnly(year, month, day));
  }
}

/// Config for daily challenge seed generation.
final class DailyChallengeConfig {
  /// Creates daily challenge config.
  const DailyChallengeConfig({
    required this.namespaceId,
    required this.modeId,
    this.schemaVersion = 1,
    this.roundCount,
  });

  /// Namespace to avoid collisions between app variants/environments.
  final String namespaceId;

  /// Mode id for different daily playlists.
  final String modeId;

  /// Explicit version for intentional sequence changes.
  final int schemaVersion;

  /// Optional number of rounds for session challenges.
  ///
  /// Supported values are currently `3`, `6`, and `10`.
  final int? roundCount;

  /// Serializes config to JSON-friendly map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'schemaVersion': _serializationSchemaV1,
      'type': 'daily_challenge_config',
      'namespaceId': namespaceId,
      'modeId': modeId,
      'dailySchemaVersion': schemaVersion,
      if (roundCount case final value?) 'roundCount': value,
    };
  }

  /// Decodes config from map without throwing.
  static DecodeResult<DailyChallengeConfig> tryFromMap(
    Map<String, dynamic> map,
  ) {
    if (map['schemaVersion'] != _serializationSchemaV1) {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unsupportedSchemaVersion,
          message: 'Unsupported schemaVersion ${map['schemaVersion']}.',
        ),
      );
    }
    if (map['type'] != 'daily_challenge_config') {
      return DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.unknownType,
          message: 'Unknown type ${map['type']}.',
        ),
      );
    }
    final namespaceId = map['namespaceId'];
    final modeId = map['modeId'];
    final dailySchemaVersion = map['dailySchemaVersion'];
    final roundCount = map['roundCount'];
    if (namespaceId is! String ||
        modeId is! String ||
        dailySchemaVersion is! int ||
        (roundCount != null && roundCount is! int)) {
      return const DecodeResult.failure(
        DecodeFailure(
          code: DecodeFailureCode.invalidPayload,
          message: 'Invalid DailyChallengeConfig payload.',
        ),
      );
    }
    return DecodeResult.success(
      DailyChallengeConfig(
        namespaceId: namespaceId,
        modeId: modeId,
        schemaVersion: dailySchemaVersion,
        roundCount: roundCount as int?,
      ),
    );
  }
}
