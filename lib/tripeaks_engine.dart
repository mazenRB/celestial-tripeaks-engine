/// Deterministic pure Dart TriPeaks engine library.
///
/// This library exposes round/session reducers, configuration DTOs,
/// replay/save/fingerprint utilities, and multiplayer orchestration types.
library;

import 'dart:convert';
import 'dart:math';

part 'src/model.dart';
part 'src/round_config.dart';
part 'src/match_scoring_types.dart';
part 'src/engine_types.dart';
part 'src/mode_bundle.dart';
part 'src/serialization.dart';
part 'src/round_state.dart';
part 'src/session_state.dart';
part 'src/daily.dart';
part 'src/deal_policy.dart';
part 'src/replay.dart';
part 'src/save.dart';
part 'src/query.dart';
part 'src/match_room.dart';
part 'src/match_competitive.dart';
part 'src/match_finalization.dart';
part 'src/server_authority.dart';
part 'src/authority_runtime_config.dart';
part 'src/authority_ports.dart';
part 'src/authority_persistence_types.dart';
part 'src/authority_runtime_errors.dart';
part 'src/authority_runtime.dart';
part 'src/authority_store_memory.dart';
part 'src/round_reducer.dart';
part 'src/session_reducer.dart';
part 'src/match_scoring_reducer.dart';
part 'src/game_wrapper.dart';
