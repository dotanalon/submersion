import 'dart:convert';

/// The `dive_tanks.shared_computer_ids` column (v260): the other computers
/// on a consolidated dive that logged this same physical cylinder.
///
/// Consolidation keeps one row for a cylinder two computers both logged
/// (same gas, agreeing pressures, or one transmitter) and attributes it to
/// the computer it merged into. Without this list the folded-in computer
/// loses the cylinder: its analysis scopes gas to its own tanks and reads
/// the dive on whatever it kept alone. Stored as a JSON array of computer
/// ids; null or blank is empty.
List<String> decodeSharedComputerIds(String? text) {
  if (text == null || text.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(text);
    if (decoded is! List) return const [];
    return List.unmodifiable(decoded.whereType<String>());
  } on FormatException {
    return const [];
  }
}

/// The stored value of a cylinder whose sharing was recorded and found
/// nobody: a fold, or the open-time inference, has handled its dive. Null
/// means never recorded, which the inference reads as a dive to infer
/// (backfillTankSharedComputers). Decodes to an empty list like null.
const String noSharedComputersRecorded = '[]';

/// Inverse of [decodeSharedComputerIds]; an empty list is stored as null.
String? encodeSharedComputerIds(Iterable<String> ids) {
  final unique = {...ids}.toList();
  return unique.isEmpty ? null : jsonEncode(unique);
}
