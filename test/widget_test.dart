// This is a basic Flutter widget test.
import 'package:flutter_test/flutter_test.dart';
import 'package:vobpl_attendance/main.dart';

void main() {
  testWidgets('App initialization smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Since main() initializes Firebase, we might need a mock for a full test,
    // but here we just check if the widget can be pumped.
    await tester.pumpWidget(const VOBPLAttendanceApp());

    // Basic check to see if the app starts
    expect(find.byType(VOBPLAttendanceApp), findsOneWidget);
  });
}
