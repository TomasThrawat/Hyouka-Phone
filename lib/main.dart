import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const PhoneApp());
}

class PhoneApp extends StatelessWidget {
  const PhoneApp({
    super.key,
    this.enableDefaultDialerPrompt = true,
    this.initialRecents = const [],
  });

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
    this.enableDefaultDialerPrompt = true,
    this.initialRecents = const [],
  });

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
  List<CallEntry> _recents = const [];
  final TextEditingController _recentSearchController = TextEditingController();
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
    _recentSearchController.dispose();
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
                if (_pendingCall != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                    child: _buildCallActions(_pendingCall!),
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
    final query = _recentSearchController.text.trim().toLowerCase();
    final visibleRecents = _recents.where((entry) {
      final searchable = '${entry.name ?? ''} ${entry.number}'.toLowerCase();
      return searchable.contains(query);
    }).toList(growable: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: TextField(
            key: const Key('recent_search_field'),
            controller: _recentSearchController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white, fontSize: 16),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              hintText: 'بحث',
              hintStyle: const TextStyle(color: Color(0xFF888888)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFFAAAAAA)),
              suffixIcon: _recentSearchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح البحث',
                      onPressed: () {
                        _recentSearchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close, color: Color(0xFFAAAAAA)),
                    ),
              filled: true,
              fillColor: Colors.black,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF333333)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF777777)),
              ),
            ),
          ),
        ),
        if (_pendingCall != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
            child: _buildCallActions(_pendingCall!),
          ),
        Expanded(
          child: visibleRecents.isEmpty
              ? Center(
                  child: Text(
                    query.isEmpty ? 'لا توجد مكالمات حديثة' : 'لا توجد نتائج',
                    style: const TextStyle(
                      color: Color(0xFFAAAAAA),
                      fontSize: 15,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 20),
                  itemCount: visibleRecents.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    color: Color(0xFF1B1B1B),
                  ),
                  itemBuilder: (context, index) {
                    final entry = visibleRecents[index];
                    return InkWell(
                      key: Key('recent_call_entry_$index'),
                      onTap: () => _selectCall(entry.number, name: entry.name),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (entry.name != null && entry.name!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 3),
                                      child: Text(
                                        entry.name!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    entry.number,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFFCCCCCC),
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _formatTime(entry.time),
                                    style: const TextStyle(
                                      color: Color(0xFF888888),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.call, color: Colors.white, size: 19),
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
