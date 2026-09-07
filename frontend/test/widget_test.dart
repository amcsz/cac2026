import 'package:flutter_test/flutter_test.dart';

import 'package:cac2026_frontend/app.dart';

void main() {
  testWidgets('SwiftGuard app starts', (tester) async {
    await tester.pumpWidget(const SwiftGuardApp());
    await tester.pump();

    expect(find.text('SwiftGuard'), findsWidgets);
  });
}
