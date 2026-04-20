import 'package:pub_api_client/pub_api_client.dart';
import 'package:test/test.dart';

void main() {
  // Reminder to upgrade objective_c dependency.
  //
  // In Apr. 2026 using the latest objective_c library version 9.3.0 resulted
  // in a warning when validating the iOS app package. As a workaround, the
  // package was downgraded and pinned to version 9.1.0.
  //
  // Because a patch is in progress, this test acts as a reminder to upgrade
  // when a new objective_c package version has been released. In that case,
  // this test will fail.
  //
  // See also:
  // - https://github.com/dart-lang/native/issues/3004#issuecomment-3921940973
  // - objective_c dependency pinned in pubspec.yaml
  const knownLatestVersion = '9.3.0';
  late PubClient client;

  setUp(() => client = PubClient());
  tearDown(() => client.close());

  test('objective_c has no release beyond known-bad 9.3.0', () async {
    final allVersions = await client.packageVersions('objective_c');
    final stableVersions = allVersions.where((v) => !v.contains('-')).toList();
    stableVersions.sort(_compareSemver);

    final latestVersion = stableVersions.last;

    expect(
      latestVersion,
      knownLatestVersion,
      reason:
          'objective_c $latestVersion has been published. '
          'Check whether the iOS validation issue is fixed, remove the '
          'explicit dependency from pubspec.yaml, and delete this test.',
    );
  });
}

/// Compares two semver strings numerically (e.g. "9.3.0" vs "9.10.0").
///
/// Required because [String.compareTo] sorts lexicographically, which gives
/// wrong results for double-digit version segments.
int _compareSemver(String a, String b) {
  final (aMajor, aMinor, aPatch, aBuild) = _parseSemver(a);
  final (bMajor, bMinor, bPatch, bBuild) = _parseSemver(b);

  if (aMajor != bMajor) return aMajor - bMajor;
  if (aMinor != bMinor) return aMinor - bMinor;
  if (aPatch != bPatch) return aPatch - bPatch;
  return aBuild - bBuild;
}

(int, int, int, int) _parseSemver(String version) {
  final buildSplit = version.split('+');
  final build = buildSplit.length > 1 ? int.parse(buildSplit[1]) : 0;
  final parts = buildSplit.first.split('.').map(int.parse).toList();
  return (parts[0], parts[1], parts[2], build);
}
