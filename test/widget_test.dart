import 'package:flutter_test/flutter_test.dart';
import 'package:phone/main.dart';

void main() {
  testWidgets('dialer renders without letter labels', (tester) async {
    await tester.pumpWidget(const PhoneApp());

    expect(find.text('هاتف'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('*'), findsOneWidget);
    expect(find.text('#'), findsOneWidget);
    expect(find.text('ABC'), findsNothing);
    expect(find.text('DEF'), findsNothing);
    expect(find.text('GHI'), findsNothing);
    expect(find.text('Phone'), findsNothing);
  });

  testWidgets('numbers can be entered and deleted', (tester) async {
    await tester.pumpWidget(const PhoneApp());

    await tester.tap(find.text('1'));
    await tester.tap(find.text('2'));
    await tester.tap(find.text('3'));
    await tester.pump();

    expect(find.text('123'), findsOneWidget);

    await tester.tap(find.byTooltip('حذف'));
    await tester.pump();

    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('clear removes the current number', (tester) async {
    await tester.pumpWidget(const PhoneApp());

    await tester.tap(find.text('5'));
    await tester.tap(find.text('5'));
    await tester.pump();

    await tester.tap(find.byTooltip('مسح الرقم'));
    await tester.pump();

    expect(find.text('55'), findsOneWidget);
    expect(find.text('هاتف'), findsOneWidget);
  });

  testWidgets('recents tab starts empty', (tester) async {
    await tester.pumpWidget(const PhoneApp());

    await tester.tap(find.text('المكالمات'));
    await tester.pump();

    expect(find.text('لا توجد مكالمات حديثة'), findsOneWidget);
  });
}
