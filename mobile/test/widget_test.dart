import 'package:flutter_test/flutter_test.dart';
import 'package:trace_app/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const TraceApp());
    expect(find.text('trace your lyf'), findsOneWidget);
  });
}
