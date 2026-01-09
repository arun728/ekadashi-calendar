import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_settings/app_settings.dart';
import 'package:share_plus/share_plus.dart';
import '../services/theme_service.dart';
import '../services/notification_service.dart';
import '../services/language_service.dart';
import '../services/ekadashi_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  bool _remind1Day = true;
  bool _remind2Days = true;
  bool _remindOnDay = true;
  bool _notificationsEnabled = true;

  bool _hasNotificationPermission = false;
  bool _hasExactAlarmPermission = true;
  bool _permissionsExpanded = false;
  bool _isInitialized = false;
  bool _isCheckingPermissions = false;

  final EkadashiService _ekadashiService = EkadashiService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isInitialized && !_isCheckingPermissions) {
      // Use post frame callback for smoother UI update
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkPermissionsAfterResume();
        }
      });
    }
  }

  Future<void> _initialize() async {
    await _loadSettings();
    await _checkAllPermissions();
    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
          _remind1Day = prefs.getBool('remind_one_day_before') ?? true;
          _remind2Days = prefs.getBool('remind_two_days_before') ?? true;
          _remindOnDay = prefs.getBool('remind_on_day') ?? true;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  /// Check all permissions - called on init
  Future<void> _checkAllPermissions() async {
    if (_isCheckingPermissions || !mounted) return;
    _isCheckingPermissions = true;

    try {
      // Check notification permission
      bool hasNotif = false;
      try {
        hasNotif = await NotificationService().hasNotificationPermission();
      } catch (e) {
        debugPrint('Notification permission check error: $e');
      }

      // Check exact alarm permission (Android only) - NO TIMEOUT with wrong default
      bool hasAlarm = true;
      if (Platform.isAndroid) {
        try {
          hasAlarm = await NotificationService().hasExactAlarmPermission();
          debugPrint('Exact alarm permission: $hasAlarm');
        } catch (e) {
          debugPrint('Alarm permission check error: $e');
          // On error, we don't know the state - assume needs check
          hasAlarm = false;
        }
      }

      if (!mounted) {
        _isCheckingPermissions = false;
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      // Sync notification state
      if (hasNotif) {
        final currentEnabled = prefs.getBool('notifications_enabled');
        // If not set or false, enable all toggles
        if (currentEnabled == null || !currentEnabled) {
          await prefs.setBool('notifications_enabled', true);
          await prefs.setBool('remind_one_day_before', true);
          await prefs.setBool('remind_two_days_before', true);
          await prefs.setBool('remind_on_day', true);
        }

        if (mounted) {
          setState(() {
            _hasNotificationPermission = true;
            _notificationsEnabled = true;
            _remind1Day = prefs.getBool('remind_one_day_before') ?? true;
            _remind2Days = prefs.getBool('remind_two_days_before') ?? true;
            _remindOnDay = prefs.getBool('remind_on_day') ?? true;
            _hasExactAlarmPermission = hasAlarm;
            _permissionsExpanded = !hasAlarm; // Expand if alarm permission missing
          });
        }
      } else {
        await prefs.setBool('notifications_enabled', false);

        if (mounted) {
          setState(() {
            _hasNotificationPermission = false;
            _notificationsEnabled = false;
            _hasExactAlarmPermission = hasAlarm;
            _permissionsExpanded = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Check all permissions error: $e');
    } finally {
      _isCheckingPermissions = false;
    }
  }

  /// Check permissions after returning from system settings
  Future<void> _checkPermissionsAfterResume() async {
    if (_isCheckingPermissions || !mounted) return;
    _isCheckingPermissions = true;

    debugPrint('🔄 Checking permissions after resume...');

    try {
      // Check notification permission
      bool hasNotif = false;
      try {
        hasNotif = await NotificationService().hasNotificationPermission();
        debugPrint('  Notification permission: $hasNotif');
      } catch (e) {
        debugPrint('  Resume notification check error: $e');
        hasNotif = _hasNotificationPermission;
      }

      // CRITICAL: Always check alarm permission fresh - don't cache or use timeout defaults
      bool hasAlarm = true;
      if (Platform.isAndroid) {
        try {
          // Force fresh check - this is the key fix
          hasAlarm = await NotificationService().hasExactAlarmPermission();
          debugPrint('  Exact alarm permission (fresh check): $hasAlarm');
        } catch (e) {
          debugPrint('  Resume alarm check error: $e');
          // On error, assume we need to check again - don't use cached value
          hasAlarm = false;
        }
      }

      if (!mounted) {
        _isCheckingPermissions = false;
        return;
      }

      // Always update state to reflect current permissions
      final prefs = await SharedPreferences.getInstance();

      if (hasNotif && !_hasNotificationPermission) {
        // Permission was granted - enable toggles
        await prefs.setBool('notifications_enabled', true);
        await prefs.setBool('remind_one_day_before', true);
        await prefs.setBool('remind_two_days_before', true);
        await prefs.setBool('remind_on_day', true);

        debugPrint('  ✅ Notification permission granted - enabling toggles');

        setState(() {
          _hasNotificationPermission = true;
          _notificationsEnabled = true;
          _remind1Day = true;
          _remind2Days = true;
          _remindOnDay = true;
          _hasExactAlarmPermission = hasAlarm;
          _permissionsExpanded = !hasAlarm;
        });
      } else if (!hasNotif && _hasNotificationPermission) {
        // Permission was revoked - disable
        await prefs.setBool('notifications_enabled', false);

        debugPrint('  ❌ Notification permission revoked - disabling toggles');

        setState(() {
          _hasNotificationPermission = false;
          _notificationsEnabled = false;
          _hasExactAlarmPermission = hasAlarm;
          _permissionsExpanded = false;
        });
      } else {
        // Notification permission unchanged - but alarm might have changed
        debugPrint('  Alarm permission changed: $_hasExactAlarmPermission -> $hasAlarm');

        setState(() {
          _hasExactAlarmPermission = hasAlarm;
          // Expand permissions section if alarm is now disabled
          if (!hasAlarm && _notificationsEnabled && _hasNotificationPermission) {
            _permissionsExpanded = true;
          }
        });
      }
    } catch (e) {
      debugPrint('Check permissions after resume error: $e');
    } finally {
      _isCheckingPermissions = false;
    }
  }

  void _rescheduleNotifications() {
    if (!_notificationsEnabled || !_hasNotificationPermission) {
      NotificationService().cancelAll();
      return;
    }

    Future.microtask(() async {
      try {
        final langService = Provider.of<LanguageService>(context, listen: false);
        final dates = await _ekadashiService.getUpcomingEkadashis(
            languageCode: langService.currentLocale.languageCode
        );

        await NotificationService().scheduleAllNotifications(
            dates, _remind1Day, _remind2Days, _remindOnDay,
            langService.localizedStrings
        );
      } catch (e) {
        debugPrint("Error rescheduling: $e");
      }
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    if (value && !_hasNotificationPermission) {
      try {
        final granted = await NotificationService().requestNotificationPermission();

        if (granted) {
          final prefs = await SharedPreferences.getInstance();

          await prefs.setBool('notifications_enabled', true);
          await prefs.setBool('remind_one_day_before', true);
          await prefs.setBool('remind_two_days_before', true);
          await prefs.setBool('remind_on_day', true);

          // Also check alarm permission after enabling notifications
          bool hasAlarm = true;
          if (Platform.isAndroid) {
            try {
              hasAlarm = await NotificationService().hasExactAlarmPermission();
            } catch (e) {
              hasAlarm = false;
            }
          }

          if (mounted) {
            setState(() {
              _hasNotificationPermission = true;
              _notificationsEnabled = true;
              _remind1Day = true;
              _remind2Days = true;
              _remindOnDay = true;
              _hasExactAlarmPermission = hasAlarm;
              _permissionsExpanded = !hasAlarm;
            });
          }

          _rescheduleNotifications();
        }
      } catch (e) {
        debugPrint('Error requesting notification permission: $e');
      }
      return;
    }

    if (mounted) {
      setState(() => _notificationsEnabled = value);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', value);

      if (value) {
        _rescheduleNotifications();
      } else {
        await NotificationService().cancelAll();
      }
    } catch (e) {
      debugPrint('Error toggling notifications: $e');
    }
  }

  Future<void> _toggleRemind1(bool value) async {
    setState(() => _remind1Day = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remind_one_day_before', value);
    _rescheduleNotifications();
  }

  Future<void> _toggleRemind2(bool value) async {
    setState(() => _remind2Days = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remind_two_days_before', value);
    _rescheduleNotifications();
  }

  Future<void> _toggleRemindOnDay(bool value) async {
    setState(() => _remindOnDay = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remind_on_day', value);
    _rescheduleNotifications();
  }

  Future<void> _openAlarmSettings() async {
    try {
      await NotificationService().openExactAlarmSettings();
    } catch (e) {
      debugPrint('Error opening alarm settings: $e');
    }
  }

  Future<void> _openAppSettings() async {
    try {
      await AppSettings.openAppSettings(type: AppSettingsType.settings);
    } catch (e) {
      debugPrint('Error opening app settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    const tealColor = Color(0xFF00A19B);

    final bool allPermissionsOK = _hasNotificationPermission && _hasExactAlarmPermission;
    final bool togglesEnabled = _hasNotificationPermission && _notificationsEnabled;

    // Show permissions section ONLY when notifications are enabled
    final bool showPermissionsSection = Platform.isAndroid && _notificationsEnabled && _hasNotificationPermission;

    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator(color: tealColor));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // APPEARANCE
        Text(lang.translate('appearance'),
            style: const TextStyle(color: tealColor, fontWeight: FontWeight.bold)),
        SwitchListTile(
          title: Text(lang.translate('dark_mode')),
          value: Provider.of<ThemeService>(context).isDarkMode,
          activeColor: tealColor,
          onChanged: (value) {
            Provider.of<ThemeService>(context, listen: false).toggleTheme(value);
          },
        ),
        const Divider(),

        // NOTIFICATIONS
        Text(lang.translate('notifications'),
            style: const TextStyle(color: tealColor, fontWeight: FontWeight.bold)),

        SwitchListTile(
          title: Text(lang.translate('enable_notifications')),
          subtitle: _hasNotificationPermission
              ? (_notificationsEnabled
              ? Text(
              lang.translateWithArgs('reminders_active', [_getEnabledCount().toString()]),
              style: const TextStyle(fontSize: 12, color: Colors.grey)
          )
              : null)
              : Text(
              lang.translate('notifications_off'),
              style: const TextStyle(fontSize: 12, color: Colors.orange)
          ),
          value: _notificationsEnabled && _hasNotificationPermission,
          activeColor: tealColor,
          onChanged: _toggleNotifications,
        ),

        SwitchListTile(
          title: Text(lang.translate('notify_start')),
          subtitle: Text(
            togglesEnabled && _remindOnDay
                ? lang.translate('status_active')
                : lang.translate('status_disabled'),
            style: TextStyle(
              fontSize: 11,
              color: togglesEnabled && _remindOnDay ? Colors.green : Colors.grey,
            ),
          ),
          value: _remindOnDay && togglesEnabled,
          activeColor: tealColor,
          onChanged: togglesEnabled ? _toggleRemindOnDay : null,
        ),

        SwitchListTile(
          title: Text(lang.translate('notify_1day')),
          subtitle: Text(
            togglesEnabled && _remind1Day
                ? lang.translate('status_active')
                : lang.translate('status_disabled'),
            style: TextStyle(
              fontSize: 11,
              color: togglesEnabled && _remind1Day ? Colors.green : Colors.grey,
            ),
          ),
          value: _remind1Day && togglesEnabled,
          activeColor: tealColor,
          onChanged: togglesEnabled ? _toggleRemind1 : null,
        ),

        SwitchListTile(
          title: Text(lang.translate('notify_2day')),
          subtitle: Text(
            togglesEnabled && _remind2Days
                ? lang.translate('status_active')
                : lang.translate('status_disabled'),
            style: TextStyle(
              fontSize: 11,
              color: togglesEnabled && _remind2Days ? Colors.green : Colors.grey,
            ),
          ),
          value: _remind2Days && togglesEnabled,
          activeColor: tealColor,
          onChanged: togglesEnabled ? _toggleRemind2 : null,
        ),

        if (togglesEnabled)
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined, color: tealColor),
            title: Text(lang.translate('test_notification')),
            subtitle: Text(
              lang.translate('test_notification_desc'),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            onTap: () async {
              try {
                final langService = Provider.of<LanguageService>(context, listen: false);
                await NotificationService().showTestNotification(langService.localizedStrings);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(lang.translate('notif_sent_msg')),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                debugPrint('Error sending test notification: $e');
              }
            },
          ),

        // PERMISSIONS - Only shown when notifications are ENABLED
        if (showPermissionsSection) ...[
          const Divider(height: 32),

          InkWell(
            onTap: () => setState(() => _permissionsExpanded = !_permissionsExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    allPermissionsOK ? Icons.check_circle : Icons.warning_amber_rounded,
                    color: allPermissionsOK ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(lang.translate('permissions'),
                      style: const TextStyle(color: tealColor, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text(
                    allPermissionsOK
                        ? lang.translate('permissions_ok')
                        : lang.translate('permissions_needed'),
                    style: TextStyle(
                      fontSize: 12,
                      color: allPermissionsOK ? Colors.green : Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _permissionsExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          if (_permissionsExpanded) ...[
            _buildPermissionRow(
              icon: _hasExactAlarmPermission ? Icons.check_circle : Icons.error_outline,
              iconColor: _hasExactAlarmPermission ? Colors.green : Colors.orange,
              title: lang.translate('alarms_reminders'),
              subtitle: _hasExactAlarmPermission
                  ? lang.translate('alarms_enabled')
                  : lang.translate('alarms_disabled'),
              subtitleColor: _hasExactAlarmPermission ? Colors.green : Colors.orange,
              showButton: true,  // Always show button for quick access
              buttonText: lang.translate('open_settings'),
              onTap: _openAlarmSettings,
              onInfoTap: _showAlarmsInfoDialog,
            ),

            _buildPermissionRow(
              icon: Icons.battery_saver,
              iconColor: tealColor,
              title: lang.translate('battery_optimization'),
              subtitle: lang.translate('battery_desc'),
              subtitleColor: Colors.grey,
              showButton: true,
              buttonText: lang.translate('open_settings'),
              onTap: _openAppSettings,
              onInfoTap: _showBatteryInfoDialog,
            ),
          ],
        ],

        const Divider(height: 32),

        // ABOUT
        Text(lang.translate('about'),
            style: const TextStyle(color: tealColor, fontWeight: FontWeight.bold)),
        ListTile(
          leading: const Icon(Icons.share, color: tealColor),
          title: Text(lang.translate('share_app')),
          subtitle: Text(
            lang.translate('share_app_desc'),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          onTap: _shareApp,
        ),
        ListTile(
          title: Text(lang.translate('version')),
          trailing: const Text("1.0.0", style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

  void _shareApp() {
    final lang = Provider.of<LanguageService>(context, listen: false);
    final shareMessage = lang.translate('share_message');
    Share.share(shareMessage);
  }

  Widget _buildPermissionRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color subtitleColor,
    required bool showButton,
    required String buttonText,
    VoidCallback? onTap,
    VoidCallback? onInfoTap,
  }) {
    const tealColor = Color(0xFF00A19B);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14)),
                    if (onInfoTap != null) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: onInfoTap,
                        child: Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(subtitle, style: TextStyle(fontSize: 11, color: subtitleColor)),
              ],
            ),
          ),
          if (showButton)
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(buttonText, style: const TextStyle(color: tealColor, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  void _showAlarmsInfoDialog() {
    final lang = Provider.of<LanguageService>(context, listen: false);
    const tealColor = Color(0xFF00A19B);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.alarm, color: tealColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                lang.translate('alarms_info_title'),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Why it's needed
              Text(
                lang.translate('alarms_info_why'),
                style: const TextStyle(fontWeight: FontWeight.bold, color: tealColor),
              ),
              const SizedBox(height: 4),
              Text(
                lang.translate('alarms_info_why_desc'),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),

              // How to enable
              Text(
                lang.translate('alarms_info_steps'),
                style: const TextStyle(fontWeight: FontWeight.bold, color: tealColor),
              ),
              const SizedBox(height: 4),
              Text(lang.translate('alarms_info_step1'), style: const TextStyle(fontSize: 14)),
              Text(lang.translate('alarms_info_step2'), style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 12),

              // Note
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lang.translate('alarms_info_note'),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(lang.translate('info_close'), style: const TextStyle(color: tealColor)),
          ),
        ],
      ),
    );
  }

  void _showBatteryInfoDialog() {
    final lang = Provider.of<LanguageService>(context, listen: false);
    const tealColor = Color(0xFF00A19B);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.battery_saver, color: tealColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                lang.translate('battery_info_title'),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Why it's needed
              Text(
                lang.translate('battery_info_why'),
                style: const TextStyle(fontWeight: FontWeight.bold, color: tealColor),
              ),
              const SizedBox(height: 4),
              Text(
                lang.translate('battery_info_why_desc'),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),

              // How to allow background usage
              Text(
                lang.translate('battery_info_steps'),
                style: const TextStyle(fontWeight: FontWeight.bold, color: tealColor),
              ),
              const SizedBox(height: 4),
              Text(lang.translate('battery_info_step1'), style: const TextStyle(fontSize: 14)),
              Text(lang.translate('battery_info_step2'), style: const TextStyle(fontSize: 14)),
              Text(lang.translate('battery_info_step3'), style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 12),

              // Note
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lang.translate('battery_info_note'),
                        style: const TextStyle(fontSize: 12, color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(lang.translate('info_close'), style: const TextStyle(color: tealColor)),
          ),
        ],
      ),
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