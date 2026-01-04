import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/theme_service.dart';
import '../services/notification_service.dart';
import '../services/language_service.dart';
import '../services/ekadashi_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _remind1Day = true;
  bool _remind2Days = true;
  bool _remindOnDay = true;
  bool _notificationsEnabled = true;

  final EkadashiService _ekadashiService = EkadashiService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _remind1Day = prefs.getBool('remind_one_day_before') ?? true;
      _remind2Days = prefs.getBool('remind_two_days_before') ?? true;
      _remindOnDay = prefs.getBool('remind_on_day') ?? true;
    });
  }

  void _rescheduleNotificationsInBackground() {
    if (!_notificationsEnabled) {
      debugPrint('⚠️ Master toggle OFF - cancelling all notifications');
      NotificationService().cancelAll();
      return;
    }

    final bool current1Day = _remind1Day;
    final bool current2Days = _remind2Days;
    final bool currentOnDay = _remindOnDay;

    debugPrint('🔄 Rescheduling with: 2-day=$current2Days, 1-day=$current1Day, on-day=$currentOnDay');

    Future.microtask(() async {
      try {
        final langService = Provider.of<LanguageService>(context, listen: false);
        final dates = await _ekadashiService.getUpcomingEkadashis(
            languageCode: langService.currentLocale.languageCode
        );

        await NotificationService().scheduleAllNotifications(
            dates,
            current1Day,
            current2Days,
            currentOnDay,
            langService.localizedStrings
        );

        debugPrint('✅ Notifications rescheduled in background');
      } catch (e) {
        debugPrint("❌ Error rescheduling: $e");
      }
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);

    if (value) {
      final remind1 = prefs.getBool('remind_one_day_before') ?? true;
      final remind2 = prefs.getBool('remind_two_days_before') ?? true;
      final remindDay = prefs.getBool('remind_on_day') ?? true;

      setState(() {
        _remind1Day = remind1;
        _remind2Days = remind2;
        _remindOnDay = remindDay;
      });

      await NotificationService().requestPermissions();

      final hasPermission = await NotificationService().hasExactAlarmPermission();
      if (!hasPermission && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '⚠️ Please enable "Alarms & reminders" in Settings → Apps → Ekadashi Calendar',
              style: TextStyle(fontSize: 13),
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }

      _rescheduleNotificationsInBackground();
    } else {
      await NotificationService().cancelAll();
    }
  }

  Future<void> _toggleRemind1(bool value) async {
    setState(() => _remind1Day = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remind_one_day_before', value);
    _rescheduleNotificationsInBackground();
  }

  Future<void> _toggleRemind2(bool value) async {
    setState(() => _remind2Days = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remind_two_days_before', value);
    _rescheduleNotificationsInBackground();
  }

  Future<void> _toggleRemindOnDay(bool value) async {
    setState(() => _remindOnDay = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remind_on_day', value);
    _rescheduleNotificationsInBackground();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    const tealColor = Color(0xFF00A19B);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
            lang.translate('appearance'),
            style: const TextStyle(
                color: tealColor,
                fontWeight: FontWeight.bold
            )
        ),
        SwitchListTile(
          title: Text(lang.translate('dark_mode')),
          value: Provider.of<ThemeService>(context).isDarkMode,
          activeColor: tealColor,
          onChanged: (value) {
            Provider.of<ThemeService>(context, listen: false).toggleTheme(value);
          },
        ),
        const Divider(),

        Text(
            lang.translate('notifications'),
            style: const TextStyle(
                color: tealColor,
                fontWeight: FontWeight.bold
            )
        ),

        // Master Toggle
        SwitchListTile(
          title: Text(lang.translate('enable_notifications')),
          subtitle: _notificationsEnabled
              ? Text('${_getEnabledCount()} of 3 reminders active',
              style: const TextStyle(fontSize: 12, color: Colors.grey))
              : null,
          value: _notificationsEnabled,
          activeColor: tealColor,
          onChanged: _toggleNotifications,
        ),

        // Sub-Toggles
        SwitchListTile(
          title: Text(lang.translate('notify_start')),
          subtitle: _remindOnDay && _notificationsEnabled
              ? const Text('✓ Active', style: TextStyle(fontSize: 11, color: Colors.green))
              : const Text('Disabled', style: TextStyle(fontSize: 11, color: Colors.grey)),
          value: _remindOnDay,
          activeColor: tealColor,
          onChanged: _notificationsEnabled ? _toggleRemindOnDay : null,
        ),
        SwitchListTile(
          title: Text(lang.translate('notify_1day')),
          subtitle: _remind1Day && _notificationsEnabled
              ? const Text('✓ Active', style: TextStyle(fontSize: 11, color: Colors.green))
              : const Text('Disabled', style: TextStyle(fontSize: 11, color: Colors.grey)),
          value: _remind1Day,
          activeColor: tealColor,
          onChanged: _notificationsEnabled ? _toggleRemind1 : null,
        ),
        SwitchListTile(
          title: Text(lang.translate('notify_2day')),
          subtitle: _remind2Days && _notificationsEnabled
              ? const Text('✓ Active', style: TextStyle(fontSize: 11, color: Colors.green))
              : const Text('Disabled', style: TextStyle(fontSize: 11, color: Colors.grey)),
          value: _remind2Days,
          activeColor: tealColor,
          onChanged: _notificationsEnabled ? _toggleRemind2 : null,
        ),

        const Divider(height: 32),

        // TESTING SECTION
        Text(
            '🧪 Notification Testing',
            style: const TextStyle(
              color: tealColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            )
        ),
        const SizedBox(height: 8),

        // Test Notification
        if (_notificationsEnabled)
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined, color: tealColor),
            title: const Text('Instant Test'),
            subtitle: const Text('Tap to send notification immediately'),
            onTap: () async {
              await NotificationService().showInstantNotification(
                  'Ekadashi Calendar',
                  'Hari Om! Your notifications are working! 🙏'
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Instant notification sent! Check your status bar.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),

        // DEBUG: 1-Minute Test
        if (_notificationsEnabled)
          ListTile(
            leading: const Icon(Icons.timer, color: Colors.orange),
            title: const Text('⚡ 1-Minute Test (DEBUG)'),
            subtitle: const Text('Schedule notification for 1 minute from NOW'),
            onTap: () async {
              final result = await NotificationService().scheduleDebugNotificationIn1Minute();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result
                          ? '⏰ Debug notification scheduled for 1 minute from now!\n\nSTAY in the app or keep screen on and wait...'
                          : '❌ Failed to schedule. Check permissions.',
                      style: const TextStyle(fontSize: 13),
                    ),
                    duration: const Duration(seconds: 4),
                    backgroundColor: result ? Colors.green : Colors.red,
                  ),
                );
              }
            },
          ),

        const Divider(),
        Text(
            lang.translate('about'),
            style: const TextStyle(
                color: tealColor,
                fontWeight: FontWeight.bold
            )
        ),
        ListTile(
          title: Text(lang.translate('version')),
          trailing: const Text("1.0.0", style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

  int _getEnabledCount() {
    int count = 0;
    if (_remindOnDay) count++;
    if (_remind1Day) count++;
    if (_remind2Days) count++;
    return count;
  }
}