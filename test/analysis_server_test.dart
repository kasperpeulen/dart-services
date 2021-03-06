// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.analyzer_server_test;

import 'package:cli_util/cli_util.dart' as cli_util;
import 'package:services/src/analysis_server.dart';
import 'package:services/src/api_classes.dart';
import 'package:unittest/unittest.dart';

String sdkPath = cli_util.getSdkDir([]).path;

String completionCode = r'''
void main() {
  int i = 0;
  i.
}
''';

String completionFilterCode = r'''
void main() {
  pr
}
''';

String quickFixesCode =
r'''
void main() {
  int i = 0
}
''';

String badFormatCode =
r'''
void main()
{
int i = 0;
}
''';

String formattedCode =
r'''
void main() {
  int i = 0;
}
''';

void defineTests() {
  AnalysisServerWrapper analysisServer;

  group('analysis_server', () {
    setUp(() {
      analysisServer = new AnalysisServerWrapper(sdkPath);
    });

    tearDown(() => analysisServer.shutdown());

    test('simple_completion', () {
      //Just after i.
      return analysisServer.complete(completionCode, 32).then(
          (CompleteResponse results) {
        expect(results.replacementLength, 0);
        expect(results.replacementOffset, 32);
        expect(completionsContains(results, "abs"), true);
        expect(completionsContains(results, "codeUnitAt"), false);
      });
    });

    test('repro #126 - completions polluted on second request', () {
      // https://github.com/dart-lang/dart-services/issues/126
      return analysisServer.complete(completionFilterCode, 17).then(
          (CompleteResponse results) {

        return analysisServer.complete(completionFilterCode, 17).then(
            (CompleteResponse results) {
          expect(results.replacementLength, 2);
          expect(results.replacementOffset, 16);
          expect(completionsContains(results, "print"), true);
          expect(completionsContains(results, "pow"), false);
        });
      });
    });

    test('simple_quickFix', () {
      //Just after i.
      return analysisServer.getFixes(quickFixesCode, 25).then(
          (FixesResponse results) {
        expect(results.fixes.length, 1);
        expect(results.fixes[0].offset, 24);
        expect(results.fixes[0].length, 1); //we need an insertion

        // We should be getting an insert ; fix
        expect(results.fixes[0].fixes.length, 1);
        CandidateFix fix = results.fixes[0].fixes[0];
        expect(fix.message.contains(";"), true);
        expect(fix.edits[0].length, 0);
        expect(fix.edits[0].offset, 25);
        expect(fix.edits[0].replacement, ";");
      });
    });

    test('simple_format', () {
      return analysisServer.format(badFormatCode, 0).then(
          (FormatResponse results) {
        expect(results.newString, formattedCode);
      });
    });
  });
}

bool completionsContains(CompleteResponse response, String completion) =>
    response.completions.any((map) => map["completion"] == completion);
