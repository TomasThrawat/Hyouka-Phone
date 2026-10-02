import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const PhoneApp());
}

class PhoneApp extends StatelessWidget {
  const PhoneApp({
    super.key,
    this.enableContacts = true,
    this.enableDefaultDialerPrompt = true,
    this.initialRecents = const [],
  });

  final bool enableContacts;
  final bool enableDefaultDialerPrompt;
  final List<CallEntry> initialRecents;

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
          surfaceContainer: Colors.black,
          primary: Colors.white,
          onPrimary: Colors.black,
          onSurface: Colors.white,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.black,
          indicatorColor: Colors.black,
        ),
      ),
      home: PhoneHomePage(
        enableContacts: enableContacts,
        enableDefaultDialerPrompt: enableDefaultDialerPrompt,
        initialRecents: initialRecents,
      ),
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
    this.enableDefaultDialerPrompt = true,
    this.initialRecents = const [],
  });

  final bool enableContacts;
  final bool enableDefaultDialerPrompt;
  final List<CallEntry> initialRecents;

  @override
  State<PhoneHomePage> createState() => _PhoneHomePageState();
}

class _PhoneHomePageState extends State<PhoneHomePage>
    with WidgetsBindingObserver {
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
  bool _defaultDialerPromptShown = false;
  bool _defaultDialerRequestInProgress = false;

  static const MethodChannel _defaultDialerChannel =
      MethodChannel('com.dailer.phone/default_dialer');

  @override
  void initState() {
    super.initState();
    _recents = List<CallEntry>.unmodifiable(widget.initialRecents);
    WidgetsBinding.instance.addObserver(this);
    _loadRecents();
    if (widget.enableContacts) {
      _loadContacts();
    } else {
      _contactsLoaded = true;
    }
    if (widget.enableDefaultDialerPrompt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybePromptForDefaultDialer();
      });
    }
  }

  Future<bool?> _isDefaultDialer() async {
    try {
      return await _defaultDialerChannel.invokeMethod<bool>(
        'isDefaultDialer',
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<void> _requestDefaultDialer() async {
    _defaultDialerRequestInProgress = true;
    try {
      await _defaultDialerChannel.invokeMethod<void>(
        'requestDefaultDialer',
      );
    } on MissingPluginException {
      // Native channel is unavailable in widget tests.
    } on PlatformException {
      if (mounted) {
        _showMessage('تعذر فتح إعداد تطبيق الهاتف الافتراضي');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadRecents();
      if (_defaultDialerRequestInProgress) {
        _defaultDialerRequestInProgress = false;
        _verifyDefaultDialerAfterRequest();
      }
    }
  }

  Future<void> _verifyDefaultDialerAfterRequest() async {
    final isDefault = await _isDefaultDialer();
    if (!mounted) return;
    if (isDefault == true) {
      _showMessage('تم تعيين هاتف كتطبيق الاتصال الافتراضي');
    } else if (isDefault == false) {
      _showMessage('النظام لم يعين هاتف كتطبيق الاتصال الافتراضي');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _maybePromptForDefaultDialer() async {
    if (_defaultDialerPromptShown || !mounted) return;
    _defaultDialerPromptShown = true;

    final isDefault = await _isDefaultDialer();
    if (!mounted || isDefault != false) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعيين هاتف كتطبيق الهاتف الافتراضي؟'),
        content: const Text(
          'يمكنك اختيار هاتف كتطبيق الاتصال الافتراضي من إعدادات النظام.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('لاحقًا'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _requestDefaultDialer();
            },
            child: const Text('تعيين كافتراضي'),
          ),
        ],
      ),
    );
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

  Future<void> _loadRecents() async {
    try {
      final raw = await _defaultDialerChannel.invokeMethod<List<dynamic>>(
        'getRecentCalls',
      );
      if (!mounted || raw == null) return;

      final recents = raw
          .whereType<Map>()
          .map((item) {
            final number = item['number']?.toString().trim() ?? '';
            final nameValue = item['name']?.toString().trim();
            final timeValue = item['time'];
            final millis = timeValue is num
                ? timeValue.toInt()
                : int.tryParse(timeValue?.toString() ?? '');
            if (millis == null || number.isEmpty) return null;

            return CallEntry(
              number: number,
              name: nameValue == null || nameValue.isEmpty ? null : nameValue,
              time: DateTime.fromMillisecondsSinceEpoch(millis),
            );
          })
          .whereType<CallEntry>()
          .take(50)
          .toList(growable: false);

      setState(() {
        _recents = List<CallEntry>.unmodifiable(recents);
      });
    } on MissingPluginException {
      // Android is unavailable in widget tests.
    } on PlatformException {
      // Keep the in-memory fallback when call-log access is unavailable.
    } catch (_) {
      // Keep the in-memory fallback for malformed platform data.
    }
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
    final dialable = _dialableNumber(number);
    if (dialable.isEmpty) return;
    setState(() {
      _number = number;
      _pendingCall = PendingCall(number: dialable, name: name);
    });
  }

  Future<void> _placeCall(String number, {String? name}) async {
    final dialable = _dialableNumber(number);
    if (dialable.isEmpty) {
      _showMessage('اكتب رقمًا للاتصال');
      return;
    }

    bool placed = false;
    try {
      placed = await _defaultDialerChannel.invokeMethod<bool>(
            'placeCall',
            <String, dynamic>{'number': dialable},
          ) ??
          false;
    } on MissingPluginException {
      // Widget tests have no Android MethodChannel. Use the URI launcher only there.
      final uri = Uri(scheme: 'tel', path: dialable);
      try {
        placed = await launchUrl(uri);
      } catch (_) {
        placed = false;
      }
    } on PlatformException catch (error) {
      _showMessage(
        error.message ?? 'تعذر بدء المكالمة',
      );
      return;
    }

    if (!placed) {
      _showMessage('تعذر بدء المكالمة');
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
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dialpad_outlined, color: Colors.white),
            selectedIcon: Icon(Icons.dialpad, color: Colors.white),
            label: '',
            tooltip: 'لوحة الأرقام',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined, color: Colors.white),
            selectedIcon: Icon(Icons.history, color: Colors.white),
            label: '',
            tooltip: 'المكالمات',
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

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'هاتف',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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
                if (_pendingCall != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                    child: _buildCallActions(_pendingCall!),
                  ),
                if (_pendingCall == null && _matches.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                    child: _buildContactMatches(),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 28 : 34,
                      ),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _keys.length,
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
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
                SizedBox(
                  height: 84,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Tooltip(
                            message: 'حذف',
                            child: Semantics(
                              button: true,
                              label: 'حذف',
                              child: GestureDetector(
                                key: const Key('delete_number_button'),
                                behavior: HitTestBehavior.opaque,
                                onTap: _number.isEmpty ? null : _delete,
                                onLongPress:
                                    _number.isEmpty ? null : _clear,
                                child: const SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: Center(
                                    child: Icon(
                                      Icons.backspace_outlined,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: 60,
                            height: 60,
                            child: FilledButton(
                              key: const Key('dialer_call_button'),
                              onPressed: _number.isEmpty
                                  ? null
                                  : () => _placeCall(_number),
                              style: FilledButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: const CircleBorder(),
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                 side: const BorderSide(color: Color(0xFF666666)),
                                 disabledBackgroundColor: Colors.black,
                                 disabledForegroundColor: const Color(0xFF888888),
                              ),
                              child: const Icon(
                                Icons.call,
                                size: 26,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildContactMatches() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 96),
      decoration: BoxDecoration(
        color: Colors.black,
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
                    backgroundColor: Colors.black,
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
        color: Colors.black,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF222222)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 58),
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
            key: const Key('pending_call_button'),
            onPressed: () => _placeCall(pending.number, name: pending.name),
            icon: const Icon(Icons.call, size: 18),
            label: const Text('اتصال'),
            style: FilledButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.black,
            ),
          ),
          const SizedBox(width: 8),
            TextButton.icon(
              key: const Key('pending_cancel_button'),
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                setState(() => _pendingCall = null);
              },
              icon: const Icon(Icons.close, size: 18),
              label: const Text('إلغاء'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB0B0B0),
                minimumSize: const Size(90, 48),
              ),
            ),
          ],
        ),
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
                color: Color(0xFF9A9A9A),
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
                key: Key('recent_call_entry_$index'),
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
                        backgroundColor: Colors.black,
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
                                color: Color(0xFFC7C7C7),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatTime(entry.time),
                              style: const TextStyle(
                                color: Color(0xFFA8A8A8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: Color(0xFF9A9A9A),
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
          backgroundColor: Colors.black,
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
