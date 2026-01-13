import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/theme_service.dart';
import '../services/language_service.dart';
import '../services/ekadashi_service.dart';
import '../services/native_settings_service.dart';
import '../services/native_notification_service.dart' show NativeNotificationService, EkadashiNotificationData, NotificationSettings;
import '../services/native_location_service.dart';
import 'city_selection_screen.dart';

/// Settings Screen - Updated to use native Kotlin services for:
/// - Permission handling (no freeze on return from system settings)
/// - Notification settings
/// - Location/city selection
///
/// Key improvements over original:
/// - No Flutter plugin freezes
/// - Native permission checks run on IO threads
/// - Faster permission state updates
/// - Added parana reminder option
/// - Added city/timezone selection
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  // Services
  final NativeSettingsService _settingsService = NativeSettingsService();
  final NativeNotificationService _notificationService = NativeNotificationService();
  final NativeLocationService _locationService = NativeLocationService();
  final EkadashiService _ekadashiService = EkadashiService();

  // State
  bool _isInitialized = false;
  bool _isCheckingPermissions = false;
  bool _permissionsExpanded = false;

  // Permission states
  PermissionStatus _permissionStatus = PermissionStatus.defaults();

  // Notification settings
  NotificationPrefs _notificationSettings = NotificationPrefs.defaults();

  // Location settings
  LocationSettings _locationSettings = LocationSettings.defaults();
  String _cityName = '';

  static const Color tealColor = Color(0xFF00A19B);

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
    await _loadAllSettings();
    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  /// Load all settings from native service - single efficient call
  Future<void> _loadAllSettings() async {
    try {
      // Get all settings at once (more efficient)
      final allSettings = await _settingsService.getAllSettings();

      // Get city name if a city is selected
      String cityName = '';
      if (allSettings.location.cityId != null) {
        final city = _ekadashiService.getCityById(allSettings.location.cityId!);
        cityName = city?.name ?? '';
      } else if (allSettings.location.autoDetect) {
        cityName = 'Auto-detect';
      }

      if (mounted) {
        setState(() {
          _permissionStatus = allSettings.permissions;
          _notificationSettings = allSettings.notifications;
          _locationSettings = allSettings.location;
          _cityName = cityName;

          // Expand permissions if something is missing and notifications are enabled
          _permissionsExpanded = _notificationSettings.enabled &&
              _permissionStatus.hasNotificationPermission &&
              !_permissionStatus.hasExactAlarmPermission;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  /// Check permissions after returning from system settings
  /// Uses native service - no freeze!
  Future<void> _checkPermissionsAfterResume() async {
    if (_isCheckingPermissions || !mounted) return;
    _isCheckingPermissions = true;

    debugPrint('🔄 Checking permissions after resume (native)...');

    try {
      // Native permission check - runs on IO thread, no freeze
      final newPermissions = await _settingsService.checkAllPermissions();

      if (!mounted) {
        _isCheckingPermissions = false;
        return;
      }

      final bool notificationChanged =
          newPermissions.hasNotificationPermission != _permissionStatus.hasNotificationPermission;
      final bool alarmChanged =
          newPermissions.hasExactAlarmPermission != _permissionStatus.hasExactAlarmPermission;

      if (notificationChanged) {
        if (newPermissions.hasNotificationPermission && !_permissionStatus.hasNotificationPermission) {
          // Permission was granted - enable notifications
          debugPrint('  ✅ Notification permission granted');
          final newSettings = _notificationSettings.copyWith(enabled: true);
          await _settingsService.updateNotificationSettings(newSettings);

          if (mounted) {
            setState(() {
              _notificationSettings = newSettings;
              _permissionsExpanded = !newPermissions.hasExactAlarmPermission;
            });
          }

          _rescheduleNotifications();
        } else if (!newPermissions.hasNotificationPermission && _permissionStatus.hasNotificationPermission) {
          // Permission was revoked - disable notifications
          debugPrint('  ❌ Notification permission revoked');
          final newSettings = _notificationSettings.copyWith(enabled: false);
          await _settingsService.updateNotificationSettings(newSettings);

          if (mounted) {
            setState(() {
              _notificationSettings = newSettings;
              _permissionsExpanded = false;
            });
          }

          await _notificationService.cancelAllNotifications();
        }
      }

      // Update permission status
      if (mounted) {
        setState(() {
          _permissionStatus = newPermissions;

          // Expand permissions if alarm is missing and notifications are enabled
          if (alarmChanged && !newPermissions.hasExactAlarmPermission &&
              _notificationSettings.enabled && newPermissions.hasNotificationPermission) {
            _permissionsExpanded = true;
          }
        });
      }

      debugPrint('  Alarm permission: ${newPermissions.hasExactAlarmPermission}');
    } catch (e) {
      debugPrint('Check permissions after resume error: $e');
    } finally {
      _isCheckingPermissions = false;
    }
  }

  void _rescheduleNotifications() {
    if (!_notificationSettings.enabled || !_permissionStatus.hasNotificationPermission) {
      _notificationService.cancelAllNotifications();
      return;
    }

    Future.microtask(() async {
      try {
        final langService = Provider.of<LanguageService>(context, listen: false);
        final ekadashis = await _ekadashiService.getUpcomingEkadashis(
            languageCode: langService.currentLocale.languageCode,
            timezone: _locationSettings.timezone
        );

        // Convert to notification data format
        final notificationData = ekadashis.map((e) => EkadashiNotificationData(
          id: e.id,
          name: e.name,
          fastingStartTime: e.fastingStartIso.isNotEmpty ? e.fastingStartIso : e.fastStartTime,
          paranaStartTime: e.paranaStartIso.isNotEmpty ? e.paranaStartIso : e.fastBreakTime,
        )).toList();

        // Update native notification service settings
        await _notificationService.updateSettings(NotificationSettings(
          enabled: _notificationSettings.enabled,
          remind2Days: _notificationSettings.remind2Days,
          remind1Day: _notificationSettings.remind1Day,
          remindOnStart: _notificationSettings.remindOnStart,
          remindOnParana: _notificationSettings.remindOnParana,
        ));

        // Schedule notifications
        await _notificationService.scheduleAllNotifications(
          ekadashis: notificationData,
          texts: langService.localizedStrings,
        );
      } catch (e) {
        debugPrint("Error rescheduling: $e");
      }
    });
  }

  // ============================================================
  // NOTIFICATION TOGGLES
  // ============================================================

  Future<void> _toggleNotifications(bool value) async {
    if (value && !_permissionStatus.hasNotificationPermission) {
      // Need to request permission - open settings
      await _settingsService.openNotificationSettings();
      return;
    }

    final newSettings = _notificationSettings.copyWith(enabled: value);

    if (mounted) {
      setState(() => _notificationSettings = newSettings);
    }

    await _settingsService.updateNotificationSettings(newSettings);

    if (value) {
      _rescheduleNotifications();
    } else {
      await _notificationService.cancelAllNotifications();
    }
  }

  Future<void> _toggleRemind2Days(bool value) async {
    final newSettings = _notificationSettings.copyWith(remind2Days: value);
    setState(() => _notificationSettings = newSettings);
    await _settingsService.updateNotificationSettings(newSettings);
    _rescheduleNotifications();
  }

  Future<void> _toggleRemind1Day(bool value) async {
    final newSettings = _notificationSettings.copyWith(remind1Day: value);
    setState(() => _notificationSettings = newSettings);
    await _settingsService.updateNotificationSettings(newSettings);
    _rescheduleNotifications();
  }

  Future<void> _toggleRemindOnStart(bool value) async {
    final newSettings = _notificationSettings.copyWith(remindOnStart: value);
    setState(() => _notificationSettings = newSettings);
    await _settingsService.updateNotificationSettings(newSettings);
    _rescheduleNotifications();
  }

  Future<void> _toggleRemindOnParana(bool value) async {
    final newSettings = _notificationSettings.copyWith(remindOnParana: value);
    setState(() => _notificationSettings = newSettings);
    await _settingsService.updateNotificationSettings(newSettings);
    _rescheduleNotifications();
  }

  // ============================================================
  // CITY SELECTION
  // ============================================================

  Future<void> _openCitySelection() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => CitySelectionScreen(
          currentCityId: _locationSettings.cityId,
          isAutoDetectEnabled: _locationSettings.autoDetect,
          onCitySelected: (cityId, timezone, autoDetect) {
            Navigator.pop(context, {
              'cityId': cityId,
              'timezone': timezone,
              'autoDetect': autoDetect,
            });
          },
        ),
      ),
    );

    if (result != null && mounted) {
      final cityId = result['cityId'] as String?;
      final timezone = result['timezone'] as String;
      final autoDetect = result['autoDetect'] as bool;

      // Update location settings
      await _settingsService.updateLocationSettings(
        autoDetect: autoDetect,
        cityId: cityId,
        timezone: timezone,
      );

      // Update native location service
      await _locationService.setAutoDetectEnabled(autoDetect);
      if (cityId != null) {
        await _locationService.setSelectedCityId(cityId);
      }
      await _locationService.setTimezone(timezone);

      // Get city name
      String cityName = '';
      if (autoDetect) {
        cityName = 'Auto-detect';
      } else if (cityId != null) {
        final city = _ekadashiService.getCityById(cityId);
        cityName = city?.name ?? '';
      }

      setState(() {
        _locationSettings = LocationSettings(
          autoDetect: autoDetect,
          cityId: cityId,
          timezone: timezone,
        );
        _cityName = cityName;
      });

      // Reschedule notifications with new timezone
      _rescheduleNotifications();
    }
  }

  // ============================================================
  // BUILD UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);

    final bool allPermissionsOK = _permissionStatus.allPermissionsGranted;
    final bool togglesEnabled = _permissionStatus.hasNotificationPermission &&
        _notificationSettings.enabled;

    // Show permissions section ONLY when notifications are enabled
    final bool showPermissionsSection = Platform.isAndroid &&
        _notificationSettings.enabled &&
        _permissionStatus.hasNotificationPermission;

    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator(color: tealColor));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ==================== APPEARANCE ====================
        Text(lang.translate('appearance'),
            style: const TextStyle(color: tealColor, fontWeight: FontWeight.bold)),
        SwitchListTile(
          title: Text(lang.translate('dark_mode')),
          value: Provider.of<ThemeService>(context).isDarkMode,
          activeColor: tealColor,
          onChanged: (value) {
            Provider.of<ThemeService>(context, listen: false).toggleTheme(value);
            _settingsService.setDarkMode(value);
          },
        ),
        const Divider(),

        // ==================== LOCATION/CITY ====================
        Text(lang.translate('location'),
            style: const TextStyle(color: tealColor, fontWeight: FontWeight.bold)),
        ListTile(
          leading: const Icon(Icons.location_city, color: tealColor),
          title: Text(lang.translate('select_city')),
          subtitle: Text(
            _cityName.isNotEmpty
                ? '$_cityName (${_locationSettings.timezone})'
                : _locationSettings.timezone,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: _openCitySelection,
        ),
        const Divider(),

        // ==================== NOTIFICATIONS ====================
        Text(lang.translate('notifications'),
            style: const TextStyle(color: tealColor, fontWeight: FontWeight.bold)),

        SwitchListTile(
          title: Text(lang.translate('enable_notifications')),
          subtitle: _permissionStatus.hasNotificationPermission
              ? (_notificationSettings.enabled
              ? Text(
              lang.translateWithArgs('reminders_active',
                  [_notificationSettings.enabledCount.toString()]),
              style: const TextStyle(fontSize: 12, color: Colors.grey)
          )
              : null)
              : Text(
              lang.translate('notifications_off'),
              style: const TextStyle(fontSize: 12, color: Colors.orange)
          ),
          value: _notificationSettings.enabled && _permissionStatus.hasNotificationPermission,
          activeColor: tealColor,
          onChanged: _toggleNotifications,
        ),

        // Remind on start (Ekadashi day)
        SwitchListTile(
          title: Text(lang.translate('notify_start')),
          subtitle: Text(
            togglesEnabled && _notificationSettings.remindOnStart
                ? lang.translate('status_active')
                : lang.translate('status_disabled'),
            style: TextStyle(
              fontSize: 11,
              color: togglesEnabled && _notificationSettings.remindOnStart
                  ? Colors.green : Colors.grey,
            ),
          ),
          value: _notificationSettings.remindOnStart && togglesEnabled,
          activeColor: tealColor,
          onChanged: togglesEnabled ? _toggleRemindOnStart : null,
        ),

        // Remind 1 day before
        SwitchListTile(
          title: Text(lang.translate('notify_1day')),
          subtitle: Text(
            togglesEnabled && _notificationSettings.remind1Day
                ? lang.translate('status_active')
                : lang.translate('status_disabled'),
            style: TextStyle(
              fontSize: 11,
              color: togglesEnabled && _notificationSettings.remind1Day
                  ? Colors.green : Colors.grey,
            ),
          ),
          value: _notificationSettings.remind1Day && togglesEnabled,
          activeColor: tealColor,
          onChanged: togglesEnabled ? _toggleRemind1Day : null,
        ),

        // Remind 2 days before
        SwitchListTile(
          title: Text(lang.translate('notify_2day')),
          subtitle: Text(
            togglesEnabled && _notificationSettings.remind2Days
                ? lang.translate('status_active')
                : lang.translate('status_disabled'),
            style: TextStyle(
              fontSize: 11,
              color: togglesEnabled && _notificationSettings.remind2Days
                  ? Colors.green : Colors.grey,
            ),
          ),
          value: _notificationSettings.remind2Days && togglesEnabled,
          activeColor: tealColor,
          onChanged: togglesEnabled ? _toggleRemind2Days : null,
        ),

        // NEW: Remind on Parana (breaking fast)
        SwitchListTile(
          title: Text(lang.translate('notify_parana')),
          subtitle: Text(
            togglesEnabled && _notificationSettings.remindOnParana
                ? lang.translate('status_active')
                : lang.translate('status_disabled'),
            style: TextStyle(
              fontSize: 11,
              color: togglesEnabled && _notificationSettings.remindOnParana
                  ? Colors.green : Colors.grey,
            ),
          ),
          value: _notificationSettings.remindOnParana && togglesEnabled,
          activeColor: tealColor,
          onChanged: togglesEnabled ? _toggleRemindOnParana : null,
        ),

        // Test notification button
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
                await _notificationService.showTestNotification(
                  langService.translate('test_notif_title'),
                  langService.translate('test_notif_body'),
                );
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

        // ==================== PERMISSIONS ====================
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
              icon: _permissionStatus.hasExactAlarmPermission
                  ? Icons.check_circle : Icons.error_outline,
              iconColor: _permissionStatus.hasExactAlarmPermission
                  ? Colors.green : Colors.orange,
              title: lang.translate('alarms_reminders'),
              subtitle: _permissionStatus.hasExactAlarmPermission
                  ? lang.translate('alarms_enabled')
                  : lang.translate('alarms_disabled'),
              subtitleColor: _permissionStatus.hasExactAlarmPermission
                  ? Colors.green : Colors.orange,
              showButton: true,
              buttonText: lang.translate('open_settings'),
              onTap: () => _settingsService.openExactAlarmSettings(),
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
              onTap: () => _settingsService.openBatteryOptimizationSettings(),
              onInfoTap: _showBatteryInfoDialog,
            ),
          ],
        ],

        const Divider(height: 32),

        // ==================== ABOUT ====================
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
          trailing: const Text("2.0.0", style: TextStyle(color: Colors.grey)),
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
              Text(
                lang.translate('alarms_info_steps'),
                style: const TextStyle(fontWeight: FontWeight.bold, color: tealColor),
              ),
              const SizedBox(height: 4),
              Text(lang.translate('alarms_info_step1'), style: const TextStyle(fontSize: 14)),
              Text(lang.translate('alarms_info_step2'), style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
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
              Text(
                lang.translate('battery_info_steps'),
                style: const TextStyle(fontWeight: FontWeight.bold, color: tealColor),
              ),
              const SizedBox(height: 4),
              Text(lang.translate('battery_info_step1'), style: const TextStyle(fontSize: 14)),
              Text(lang.translate('battery_info_step2'), style: const TextStyle(fontSize: 14)),
              Text(lang.translate('battery_info_step3'), style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
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
}