import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dialer renders without letter labels', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PhoneApp(enableContacts: false));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('هاتف'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
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
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PhoneApp(enableContacts: false));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('1'));
    await tester.tap(find.text('2'));
    await tester.tap(find.text('3'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('123'), findsOneWidget);

    await tester.tap(find.byTooltip('حذف'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('clear removes the current number', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PhoneApp(enableContacts: false));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('5'));
    await tester.tap(find.text('5'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('55'), findsOneWidget);

    await tester.tap(find.byTooltip('مسح الرقم'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('55'), findsNothing);
  });

  testWidgets('selecting a number shows call and cancel actions', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PhoneApp(enableContacts: false));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('1'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('2'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('3'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('123'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.call).last);
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('اتصال'), findsOneWidget);
    expect(find.text('إلغاء'), findsOneWidget);
  });

  testWidgets('recents tab starts empty', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PhoneApp(enableContacts: false));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('المكالمات'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('لا توجد مكالمات حديثة'), findsOneWidget);
  });
}
