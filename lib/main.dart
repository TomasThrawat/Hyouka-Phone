import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _callChannel = MethodChannel('hyouka_phone/calls');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HyoukaPhoneApp());
}

class HyoukaPhoneApp extends StatelessWidget {
  const HyoukaPhoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Phone',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090A0D),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7CFFB2),
          brightness: Brightness.dark,
        ),
      ),
      home: const PhoneHomePage(),
    );
  }
}

class CallEntry {
  const CallEntry({required this.number, required this.time});
  final String number;
  final DateTime time;
}

class PhoneHomePage extends StatefulWidget {
  const PhoneHomePage({super.key});

  @override
  State<PhoneHomePage> createState() => _PhoneHomePageState();
}

class _PhoneHomePageState extends State<PhoneHomePage> {
  String _number = '';
  int _tab = 0;
  final List<CallEntry> _recents = <CallEntry>[];

  static const _keys = <({String value, String letters})>[
    (value: '1', letters: ''),
    (value: '2', letters: 'ABC'),
    (value: '3', letters: 'DEF'),
    (value: '4', letters: 'GHI'),
    (value: '5', letters: 'JKL'),
    (value: '6', letters: 'MNO'),
    (value: '7', letters: 'PQRS'),
    (value: '8', letters: 'TUV'),
    (value: '9', letters: 'WXYZ'),
    (value: '*', letters: ''),
    (value: '0', letters: '+'),
    (value: '#', letters: ''),
  ];

  void _append(String value) {
    setState(() => _number += value);
  }

  void _delete() {
    if (_number.isEmpty) return;
    setState(() => _number = _number.substring(0, _number.length - 1));
  }

  Future<void> _call() async {
    final normalized = _number.replaceAll(RegExp('[\\s()-]'), '');
    if (normalized.isEmpty) {
      _showMessage('Enter a phone number first.');
      return;
    }

    try {
      await _callChannel.invokeMethod<void>('placeCall', normalized);
      setState(() {
        _recents.insert(0, CallEntry(number: normalized, time: DateTime.now()));
        if (_recents.length > 20) _recents.removeLast();
      });
    } on PlatformException catch (error) {
      _showMessage(error.message ?? 'Unable to place the call.');
    } catch (_) {
      _showMessage('Unable to place the call.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  Text(
                    'Phone',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Clear number',
                    onPressed: _number.isEmpty ? null : () => setState(() => _number = ''),
                    icon: const Icon(Icons.clear_all_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [_buildKeypad(), _buildRecents()],
              ),
            ),
            NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (index) => setState(() => _tab = index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dialpad_outlined),
                  selectedIcon: Icon(Icons.dialpad_rounded),
                  label: 'Keypad',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history_rounded),
                  label: 'Recents',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        const Spacer(),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(
            _number.isEmpty ? 'Enter number' : _number,
            key: ValueKey(_number),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w400,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 10),
        IconButton(
          tooltip: 'Delete',
          onPressed: _number.isEmpty ? null : _delete,
          icon: const Icon(Icons.backspace_outlined, size: 20),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _keys.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisExtent: 72,
              mainAxisSpacing: 12,
              crossAxisSpacing: 14,
            ),
            itemBuilder: (context, index) {
              final key = _keys[index];
              return _DialKey(
                value: key.value,
                letters: key.letters,
                onTap: () => _append(key.value),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        FloatingActionButton(
          heroTag: 'call',
          onPressed: _call,
          tooltip: 'Call',
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.black,
          child: const Icon(Icons.call_rounded),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRecents() {
    if (_recents.isEmpty) {
      return const Center(child: Text('No recent calls', style: TextStyle(fontSize: 17)));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      itemCount: _recents.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = _recents[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.call_made_rounded),
          ),
          title: Text(entry.number),
          subtitle: Text(_formatTime(entry.time)),
          trailing: IconButton(
            tooltip: 'Call again',
            onPressed: () {
              setState(() => _number = entry.number);
              _call();
            },
            icon: const Icon(Icons.call_rounded),
          ),
        );
      },
    );
  }
}

class _DialKey extends StatelessWidget {
  const _DialKey({
    required this.value,
    required this.letters,
    required this.onTap,
  });

  final String value;
  final String letters;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        shape: const CircleBorder(),
        padding: EdgeInsets.zero,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w400, height: 1.0),
          ),
          if (letters.isNotEmpty)
            Text(
              letters,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 1.6,
                height: 1.0,
              ),
            ),
        ],
      ),
    );
  }
}
