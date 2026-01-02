import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/theme_service.dart';
import '../services/notification_service.dart';
import '../services/language_service.dart';

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

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    if (value) {
      // Re-enable all sub-toggles by default if they were off
      await prefs.setBool('remind_one_day_before', true);
      await prefs.setBool('remind_two_days_before', true);
      await prefs.setBool('remind_on_day', true);
      setState(() {
        _notificationsEnabled = true;
        _remind1Day = true;
        _remind2Days = true;
        _remindOnDay = true;
      });
      // Re-request permissions just in case
      await NotificationService().requestPermissions();
    } else {
      setState(() => _notificationsEnabled = false);
      await NotificationService().cancelAll();
    }
  }

  Future<void> _toggleRemind1(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remind_one_day_before', value);
    setState(() => _remind1Day = value);
  }

  Future<void> _toggleRemind2(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remind_two_days_before', value);
    setState(() => _remind2Days = value);
  }

  Future<void> _toggleRemindOnDay(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remind_on_day', value);
    setState(() => _remindOnDay = value);
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    const tealColor = Color(0xFF00A19B);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(lang.translate('appearance'), style: const TextStyle(color: tealColor, fontWeight: FontWeight.bold)),
        SwitchListTile(
          title: Text(lang.translate('dark_mode')),
          value: Provider.of<ThemeService>(context).isDarkMode,
          activeColor: tealColor,
          onChanged: (value) {
            Provider.of<ThemeService>(context, listen: false).toggleTheme(value);
          },
        ),
        const Divider(),
        Text(lang.translate('notifications'), style: const TextStyle(color: tealColor, fontWeight: FontWeight.bold)),

        // Master Toggle
        SwitchListTile(
          title: Text(lang.translate('enable_notifications')),
          value: _notificationsEnabled,
          activeColor: tealColor,
          onChanged: _toggleNotifications,
        ),

        // Sub-Toggles
        SwitchListTile(
          title: Text(lang.translate('notify_start')),
          value: _remindOnDay,
          activeColor: tealColor,
          onChanged: _notificationsEnabled ? _toggleRemindOnDay : null,
        ),
        SwitchListTile(
          title: Text(lang.translate('notify_1day')),
          value: _remind1Day,
          activeColor: tealColor,
          onChanged: _notificationsEnabled ? _toggleRemind1 : null,
        ),
        SwitchListTile(
          title: Text(lang.translate('notify_2day')),
          value: _remind2Days,
          activeColor: tealColor,
          onChanged: _notificationsEnabled ? _toggleRemind2 : null,
        ),

        // NEW: Instant Test Option
        if (_notificationsEnabled)
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined, color: tealColor),
            title: Text(lang.translate('test_notification') ?? 'Test Notification Now'),
            subtitle: const Text('Tap to send an instant alert'),
            onTap: () async {
              await NotificationService().showInstantNotification(
                  'Ekadashi Calendar',
                  'Hari Om! Notifications are working perfectly on your device.'
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Test notification sent! Check your status bar.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),

        const Divider(),
        Text(lang.translate('about'), style: const TextStyle(color: tealColor, fontWeight: FontWeight.bold)),
        ListTile(
          title: Text(lang.translate('version')),
          trailing: const Text("1.0.0", style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}