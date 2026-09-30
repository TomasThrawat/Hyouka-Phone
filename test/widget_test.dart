import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyouka_phone/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dialer app renders keypad', (tester) async {
    await tester.pumpWidget(const HyoukaPhoneApp());

    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
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

  testWidgets('call action sends number to native channel', (tester) async {
    const channel = MethodChannel('hyouka_phone/calls');
    String? received;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'placeCall') {
        received = call.arguments as String;
      }
      return null;
    });

    await tester.pumpWidget(const HyoukaPhoneApp());

    for (final digit in ['0', '1', '2', '3', '4']) {
      await tester.tap(find.text(digit));
    }
    await tester.tap(find.byTooltip('Call'));
    await tester.pump();

    expect(received, '01234');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}
