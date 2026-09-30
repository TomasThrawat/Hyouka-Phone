import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const PhoneApp());
}

class PhoneApp extends StatelessWidget {
  const PhoneApp({
    super.key,
    this.enableContacts = true,
  });

  final bool enableContacts;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'هاتف',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          surface: Colors.black,
          surfaceContainer: Color(0xFF111111),
          primary: Colors.white,
          onPrimary: Colors.black,
          onSurface: Colors.white,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.black,
          indicatorColor: Color(0xFF242424),
        ),
      ),
      home: PhoneHomePage(enableContacts: enableContacts),
    );
  }
}

class CallEntry {
  const CallEntry({
    required this.number,
    required this.time,
    this.name,
  });

  final String number;
  final DateTime time;
  final String? name;
}

class PendingCall {
  const PendingCall({
    required this.number,
    this.name,
  });

  final String number;
  final String? name;
}

class PhoneHomePage extends StatefulWidget {
  const PhoneHomePage({
    super.key,
    this.enableContacts = true,
  });

  final bool enableContacts;

  @override
  State<PhoneHomePage> createState() => _PhoneHomePageState();
}

class _PhoneHomePageState extends State<PhoneHomePage> {
  static const _keys = <String>[
    '1', '2', '3',
    '4', '5', '6',
    '7', '8', '9',
    '*', '0', '#',
  ];

  String _number = '';
  int _tab = 0;
  bool _loadingContacts = false;
  bool _contactsLoaded = false;
  List<Contact> _contacts = const [];
  List<CallEntry> _recents = const [];
  PendingCall? _pendingCall;

  @override
  void initState() {
    super.initState();
    if (widget.enableContacts) {
      _loadContacts();
    } else {
      _contactsLoaded = true;
    }
  }

  String _digitsOnly(String value) {
    const replacements = <String, String>{
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
      '۰': '0',
      '۱': '1',
      '۲': '2',
      '۳': '3',
      '۴': '4',
      '۵': '5',
      '۶': '6',
      '۷': '7',
      '۸': '8',
      '۹': '9',
    };

    var output = value;
    replacements.forEach((from, to) => output = output.replaceAll(from, to));
    return output.replaceAll(RegExp(r'\D'), '');
  }

  String _dialableNumber(String value) {
    return value
        .replaceAll(RegExp(r'[\s()\-]'), '')
        .replaceAll(RegExp(r'[^0-9+*#]'), '');
  }

  Future<void> _loadContacts() async {
    if (_contactsLoaded || _loadingContacts) return;
    setState(() => _loadingContacts = true);

    try {
      final permission = await FlutterContacts.permissions.request(PermissionType.read);
      if (permission == PermissionStatus.granted ||
          permission == PermissionStatus.limited) {
        final contacts = await FlutterContacts.getAll(
          properties: const {
            ContactProperty.name,
            ContactProperty.phone,
          },
        );

        if (mounted) {
          setState(() {
            _contacts = contacts;
            _contactsLoaded = true;
          });
        }
      } else if (mounted) {
        setState(() => _contactsLoaded = true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _contactsLoaded = true);
      }
    } finally {
      if (mounted) setState(() => _loadingContacts = false);
    }
  }

  List<_ContactMatch> get _matches {
    final typed = _digitsOnly(_number);
    if (typed.isEmpty || !_contactsLoaded) return const [];

    final results = <_ContactMatch>[];
    final seen = <String>{};

    for (final contact in _contacts) {
      for (final phone in contact.phones) {
        final raw = phone.number.trim();
        final digits = _digitsOnly(raw);
        if (digits.isEmpty) continue;

        final matches =
            digits == typed || digits.endsWith(typed) || digits.contains(typed);
        if (!matches) continue;

        final key = '${contact.id.toString()}:$raw';
        if (seen.add(key)) {
          results.add(
            _ContactMatch(
              name: contact.displayName?.trim().isNotEmpty == true
                  ? contact.displayName!.trim()
                  : raw,
              number: raw,
            ),
          );
        }
      }
    }

    return results.take(5).toList(growable: false);
  }

  void _append(String value) {
    setState(() {
      _number += value;
      _pendingCall = null;
    });
  }

  void _delete() {
    if (_number.isEmpty) return;
    setState(() {
      _number = _number.substring(0, _number.length - 1);
      _pendingCall = null;
    });
  }

  void _clear() {
    setState(() {
      _number = '';
      _pendingCall = null;
    });
  }

  void _selectCall(String number, {String? name}) {
    setState(() {
      _number = number;
      _pendingCall = PendingCall(number: number, name: name);
    });
  }

  Future<void> _placeCall(String number, {String? name}) async {
    final dialable = _dialableNumber(number);
    if (dialable.isEmpty) {
      _showMessage('اكتب رقمًا للاتصال');
      return;
    }

    final uri = Uri(scheme: 'tel', path: dialable);
    bool launched = false;
    try {
      launched = await launchUrl(uri);
    } catch (_) {
      launched = false;
    }

    if (!launched) {
      _showMessage('تعذر فتح تطبيق الهاتف');
      return;
    }

    setState(() {
      _recents = [
        CallEntry(number: dialable, name: name, time: DateTime.now()),
        ..._recents,
      ].take(20).toList(growable: false);
      _pendingCall = null;
      _number = dialable;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.hour >= 12 ? 'م' : 'ص';
    return '${hour.toString()}:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: IndexedStack(
          index: _tab,
          children: [
            _buildDialer(),
            _buildRecents(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dialpad_outlined),
            selectedIcon: Icon(Icons.dialpad),
            label: 'لوحة الأرقام',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'المكالمات',
          ),
        ],
      ),
    );
  }

  Widget _buildDialer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 690;
        final keySize = compact ? 56.0 : 62.0;
        final gap = compact ? 10.0 : 12.0;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'هاتف',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _number.isEmpty ? null : _clear,
                    tooltip: 'مسح الرقم',
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  _number.isEmpty ? ' ' : _number,
                  key: ValueKey(_number),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 30 : 34,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            if (_loadingContacts && !_contactsLoaded)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (_matches.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: _buildContactMatches(),
              ),
            if (_pendingCall != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                child: _buildCallActions(_pendingCall!),
              ),
            const SizedBox(height: 18),
            Flexible(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 28 : 34),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _keys.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: gap,
                      crossAxisSpacing: gap,
                      mainAxisExtent: keySize,
                    ),
                    itemBuilder: (context, index) {
                      final value = _keys[index];
                      return _DialKey(
                        value: value,
                        onTap: () => _append(value),
                        size: keySize,
                      );
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 10, 28, 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _number.isEmpty ? null : _delete,
                    tooltip: 'حذف',
                    icon: const Icon(Icons.backspace_outlined, size: 22),
                  ),
                  const SizedBox(width: 20),
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: FilledButton(
                      onPressed: _number.isEmpty ? null : () => _selectCall(_number),
                      style: FilledButton.styleFrom(
                        shape: const CircleBorder(),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: const Color(0xFF1A1A1A),
                        disabledForegroundColor: const Color(0xFF575757),
                      ),
                      child: const Icon(Icons.call, size: 26),
                    ),
                  ),
                  const SizedBox(width: 20),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContactMatches() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 190),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _matches.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF202020)),
        itemBuilder: (context, index) {
          final match = _matches[index];
          return InkWell(
            onTap: () => _selectCall(match.number, name: match.name),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 19,
                    backgroundColor: Color(0xFF1E1E1E),
                    child: Icon(Icons.person_outline, size: 21, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          match.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          match.number,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFAAAAAA),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFF777777)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCallActions(PendingCall pending) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF222222)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (pending.name != null && pending.name!.isNotEmpty)
                  Text(
                    pending.name!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(
                  pending.number,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFB0B0B0),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: () => _placeCall(pending.number, name: pending.name),
            icon: const Icon(Icons.call, size: 18),
            label: const Text('اتصال'),
            style: FilledButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF252525),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => setState(() => _pendingCall = null),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('إلغاء'),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFB0B0B0)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecents() {
    if (_recents.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.phone_in_talk_outlined,
                size: 42,
                color: Color(0xFF666666),
              ),
              SizedBox(height: 12),
              Text(
                'لا توجد مكالمات حديثة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (_pendingCall != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: _buildCallActions(_pendingCall!),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
            itemCount: _recents.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              color: Color(0xFF1B1B1B),
            ),
            itemBuilder: (context, index) {
              final entry = _recents[index];
              return InkWell(
                onTap: () => _selectCall(
                  entry.number,
                  name: entry.name,
                ),
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 22,
                        backgroundColor: Color(0xFF151515),
                        child: Icon(
                          Icons.call_made,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (entry.name != null &&
                                entry.name!.isNotEmpty)
                              Text(
                                entry.name!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            Text(
                              entry.number,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFB5B5B5),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatTime(entry.time),
                              style: const TextStyle(
                                color: Color(0xFF696969),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: Color(0xFF666666),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ContactMatch {
  const _ContactMatch({
    required this.name,
    required this.number,
  });

  final String name;
  final String number;
}

class _DialKey extends StatelessWidget {
  const _DialKey({
    required this.value,
    required this.onTap,
    required this.size,
  });

  final String value;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: const Color(0xFF121212),
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
        ),
        child: Text(
          value,
          style: TextStyle(
            fontSize: size < 60 ? 21 : 22,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
