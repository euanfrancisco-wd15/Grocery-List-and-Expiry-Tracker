import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_tracker/app.dart';

void main() {
  testWidgets('shows Firebase setup foundation', (tester) async {
    await tester.pumpWidget(const GroceryTrackerApp(firebaseError: 'missing'));

    expect(find.text('Grocery Tracker'), findsOneWidget);
    expect(
      find.text(
        'Firebase configuration is needed before authentication can start.',
      ),
      findsOneWidget,
    );
  });
}
