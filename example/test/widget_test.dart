import 'package:flutter_test/flutter_test.dart';
import 'package:ntbp_plugin_example/main.dart';

void main() {
  testWidgets('home screen renders with sample labels', (tester) async {
    await tester.pumpWidget(const NtbpExampleApp());
    await tester.pump();
    expect(find.text('Label Printer'), findsOneWidget);
    expect(find.text('No printer connected'), findsOneWidget);
    expect(find.text('Labels in series'), findsOneWidget);
    expect(find.textContaining('BK-1025'), findsWidgets);
  });
}
