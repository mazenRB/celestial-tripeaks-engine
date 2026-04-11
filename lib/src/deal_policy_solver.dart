part of 'tripeaks_engine_internal.dart';

final class _SolvabilitySolver {
  _SolvabilitySolver({
    required TriPeaksState state,
    required this.nodeLimit,
  })  : _tableau = state.tableau,
        _stock = state.stock,
        _startWasteTop = state.wasteTop,
        _rules = state.roundRulesConfig,
        _startRemovedMask = _removedMaskFromList(state.removed);

  final List<Card> _tableau;
  final List<Card> _stock;
  final Card _startWasteTop;
  final RoundRulesConfig _rules;
  final int _startRemovedMask;
  final int nodeLimit;

  final Map<String, bool> _memo = <String, bool>{};
  int _nodesVisited = 0;

  static const int _allRemovedMask = (1 << 28) - 1;

  static int _removedMaskFromList(List<bool> removed) {
    var mask = 0;
    for (var i = 0; i < removed.length; i++) {
      if (removed[i]) {
        mask |= (1 << i);
      }
    }
    return mask;
  }

  bool solve() {
    return _solveNode(
      _startRemovedMask,
      0,
      _cardId(_startWasteTop),
    );
  }

  bool _solveNode(int removedMask, int stockIndex, int wasteCardId) {
    if (removedMask == _allRemovedMask) {
      return true;
    }
    if (_nodesVisited >= nodeLimit) {
      return false;
    }
    _nodesVisited++;

    final key = '$removedMask|$stockIndex|$wasteCardId';
    final cached = _memo[key];
    if (cached != null) {
      return cached;
    }

    final wasteRank = _rankFromCardId(wasteCardId);

    for (var index = 0; index < 28; index++) {
      if (_isRemoved(removedMask, index)) {
        continue;
      }
      if (!_isExposed(removedMask, index)) {
        continue;
      }
      final candidate = _tableau[index];
      if (!TriPeaksState._areAdjacentRanks(candidate.rank, wasteRank, _rules)) {
        continue;
      }
      final nextRemoved = removedMask | (1 << index);
      if (_solveNode(nextRemoved, stockIndex, _cardId(candidate))) {
        _memo[key] = true;
        return true;
      }
    }

    if (stockIndex < _stock.length) {
      final nextWaste = _stock[stockIndex];
      if (_solveNode(removedMask, stockIndex + 1, _cardId(nextWaste))) {
        _memo[key] = true;
        return true;
      }
    }

    _memo[key] = false;
    return false;
  }

  bool _isRemoved(int removedMask, int index) {
    return ((removedMask >> index) & 1) == 1;
  }

  bool _isExposed(int removedMask, int index) {
    final blockers = _blockingIndices[index];
    for (final blocker in blockers) {
      if (!_isRemoved(removedMask, blocker)) {
        return false;
      }
    }
    return true;
  }

  int _cardId(Card card) {
    return card.suit.index * Rank.values.length + card.rank.index;
  }

  Rank _rankFromCardId(int cardId) {
    final rankIndex = cardId % Rank.values.length;
    return Rank.values[rankIndex];
  }
}

const List<List<int>> _blockingIndices = <List<int>>[
  <int>[3, 4],
  <int>[5, 6],
  <int>[7, 8],
  <int>[9, 10],
  <int>[10, 11],
  <int>[12, 13],
  <int>[13, 14],
  <int>[15, 16],
  <int>[16, 17],
  <int>[18, 19],
  <int>[19, 20],
  <int>[20, 21],
  <int>[21, 22],
  <int>[22, 23],
  <int>[23, 24],
  <int>[24, 25],
  <int>[25, 26],
  <int>[26, 27],
  <int>[],
  <int>[],
  <int>[],
  <int>[],
  <int>[],
  <int>[],
  <int>[],
  <int>[],
  <int>[],
  <int>[],
];
