import 'package:flutter_test/flutter_test.dart';
import 'package:hyouka_phone/main.dart';

void main() {
  testWidgets('dialer renders keypad and navigation', (tester) async {
    await tester.pumpWidget(const HyoukaPhoneApp());

    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('*'), findsOneWidget);
    expect(find.text('#'), findsOneWidget);
    expect(find.text('Keypad'), findsOneWidget);
    expect(find.text('Recents'), findsOneWidget);
  });

  testWidgets('numbers can be entered and deleted', (tester) async {
    await tester.pumpWidget(const HyoukaPhoneApp());

    await tester.tap(find.text('1'));
    await tester.tap(find.text('2'));
    await tester.tap(find.text('3'));
    await tester.pump();

    expect(find.text('123'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete'));
    await tester.pump();

    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('clear button removes the current number', (tester) async {
    await tester.pumpWidget(const HyoukaPhoneApp());

    await tester.tap(find.text('5'));
    await tester.tap(find.text('5'));
    await tester.pump();

    expect(find.text('55'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear number'));
    await tester.pump();

    expect(find.text('Enter number'), findsOneWidget);
  });

  testWidgets('recents tab starts empty', (tester) async {
    await tester.pumpWidget(const HyoukaPhoneApp());

    await tester.tap(find.text('Recents'));
    await tester.pump();

    expect(find.text('No recent calls'), findsOneWidget);
  });
}
