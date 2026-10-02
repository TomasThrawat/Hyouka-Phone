import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:phone/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dialer renders without letter labels', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PhoneApp(enableContacts: false, enableDefaultDialerPrompt: false));
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

    await tester.pumpWidget(const PhoneApp(enableContacts: false, enableDefaultDialerPrompt: false));
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

  testWidgets('delete can clear the current number', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PhoneApp(enableContacts: false, enableDefaultDialerPrompt: false));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('5'));
    await tester.tap(find.text('5'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('55'), findsOneWidget);

    final deleteButton = find.byKey(const Key('delete_number_button'));
    expect(deleteButton, findsOneWidget);
    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton, warnIfMissed: false);
    await tester.tap(deleteButton, warnIfMissed: false);
    await tester.pump();

    expect(find.text('55'), findsNothing);
  });

  testWidgets('call button invokes Android call bridge', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.dailer.phone/default_dialer'),
      (call) async {
        calls.add(call);
        if (call.method == 'placeCall') return true;
        return false;
      },
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.dailer.phone/default_dialer'),
        null,
      ),
    );

    await tester.pumpWidget(const PhoneApp(
      enableContacts: false,
      enableDefaultDialerPrompt: false,
    ));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('1'));
    await tester.tap(find.text('2'));
    await tester.tap(find.text('3'));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('dialer_call_button')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      calls.any(
        (call) =>
            call.method == 'placeCall' &&
            (call.arguments as Map)['number'] == '123',
      ),
      isTrue,
    );
  });

  testWidgets('selected number shows working call and cancel actions', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final calls = <MethodCall>[];
    final channel = const MethodChannel('com.dailer.phone/default_dialer');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'placeCall';
    });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await tester.pumpWidget(PhoneApp(
      enableContacts: false,
      enableDefaultDialerPrompt: false,
      initialRecents: [
        CallEntry(
          number: '456',
          name: 'Test contact',
          time: DateTime(2026, 1, 1, 12),
        ),
      ],
    ));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.history_outlined));
    await tester.pump();

    final recentEntry = find.byKey(const Key('recent_call_entry_0'));
    expect(recentEntry, findsOneWidget);
    expect(find.text('456'), findsOneWidget);

    await tester.tap(recentEntry);
    await tester.pump();

    expect(find.byKey(const Key('pending_call_button')), findsOneWidget);
    expect(find.byKey(const Key('pending_cancel_button')), findsOneWidget);
    expect(find.text('اتصال'), findsOneWidget);
    expect(find.text('إلغاء'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pending_call_button')));
    await tester.pumpAndSettle();

    expect(
      calls.any(
        (call) =>
            call.method == 'placeCall' &&
            (call.arguments as Map)['number'] == '456',
      ),
      isTrue,
    );

    // Select the same recent again and verify cancel clears the action card.
    await tester.tap(recentEntry);
    await tester.pump();
    expect(find.byKey(const Key('pending_cancel_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('pending_cancel_button')));
    await tester.pump();

    expect(find.byKey(const Key('pending_call_button')), findsNothing);
    expect(find.byKey(const Key('pending_cancel_button')), findsNothing);
  });

  testWidgets('long press on delete clears the whole number', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PhoneApp(enableContacts: false, enableDefaultDialerPrompt: false));
    await tester.pump();

    await tester.tap(find.text('7'));
    await tester.tap(find.text('8'));
    await tester.tap(find.text('9'));
    await tester.pump();

    expect(find.text('789'), findsOneWidget);

    final deleteButton = find.byKey(const Key('delete_number_button'));
    expect(deleteButton, findsOneWidget);
    await tester.ensureVisible(deleteButton);
    await tester.longPress(deleteButton);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('789'), findsNothing);
  });

  testWidgets('recents tab starts empty', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PhoneApp(enableContacts: false, enableDefaultDialerPrompt: false));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.history_outlined));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('لا توجد مكالمات حديثة'), findsOneWidget);
  });  testWidgets('bottom navigation uses icons only', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PhoneApp(
      enableContacts: false,
      enableDefaultDialerPrompt: false,
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('لوحة الأرقام'), findsNothing);
    expect(find.text('المكالمات'), findsNothing);
  });

  testWidgets('native call history refresh populates recents', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final channel = const MethodChannel('com.dailer.phone/default_dialer');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getRecentCalls') {
        return <Map<String, Object?>>[
          <String, Object?>{
            'number': '789',
            'name': 'History contact',
            'time': DateTime(2026, 10, 1, 15, 30).millisecondsSinceEpoch,
          },
        ];
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(const PhoneApp(
      enableContacts: false,
      enableDefaultDialerPrompt: false,
    ));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byIcon(Icons.history_outlined));
    await tester.pump();

    expect(find.byKey(const Key('recent_call_entry_0')), findsOneWidget);
    expect(find.text('789'), findsOneWidget);
    expect(find.text('History contact'), findsOneWidget);
  });


}
