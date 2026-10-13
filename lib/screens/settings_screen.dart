import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/theme_service.dart';
import '../services/language_service.dart';
import '../services/ekadashi_service.dart';
import '../services/tradition_service.dart';
import '../services/native_settings_service.dart';
import '../services/native_notification_service.dart' show NativeNotificationService, NotificationSettings;
import '../services/notification_service.dart';
import '../services/tradition_notification_helper.dart';
import 'package:intl/intl.dart';
import '../services/native_location_service.dart';
import '../services/panchang_calculator.dart';
import 'widgets/city_picker_dialog.dart';
import 'food_guide_screen.dart';

/// Settings Screen - Updated to use native Kotlin services for:
/// - Permission handling (no freeze on return from system settings)
/// - Notification settings
///
/// Key improvements over original:
/// - No Flutter plugin freezes
/// - Native permission checks run on IO threads
/// - Faster permission state updates
/// - Added parana reminder option (Break Fasting Reminder)
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  // Services
  final NativeSettingsService _settingsService = NativeSettingsService();
  final NativeNotificationService _notificationService = NativeNotificationService();
  final EkadashiService _ekadashiService = EkadashiService();

  // State
  bool _isInitialized = false;

  // Permission states
  PermissionStatus _permissionStatus = PermissionStatus.defaults();

  // Notification settings
  NotificationPrefs _notificationSettings = NotificationPrefs.defaults();

  // Location settings
  String _currentTimezone = 'IST';
  LocationData? _currentLocation;
  bool _isAutoDetect = true;

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
    if (state == AppLifecycleState.resumed) {
      // Debounce to avoid freeze on return
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _checkPermissionsAfterResume();
          }
        });
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
      final locService = NativeLocationService();
      final loc = await locService.getCachedLocation() ?? await locService.getCurrentLocation();
      final isAuto = await locService.isAutoDetectEnabled();

      if (mounted) {
        setState(() {
          _permissionStatus = allSettings.permissions;
          _notificationSettings = allSettings.notifications;
          _currentTimezone = loc?.timezone ?? allSettings.location.timezone;
          _currentLocation = loc;
          _isAutoDetect = isAuto;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _checkPermissionsAfterResume() async {
    if (!mounted) return;

    // Capture previous state to detect changes
    final previousPermission = _permissionStatus.hasNotificationPermission;

    // 1. Fetch latest settings (includes permissions and notifications)
    final allSettings = await _settingsService.getAllSettings();
    if (!mounted) return;

    setState(() {
      _permissionStatus = allSettings.permissions;
      // 2. Sync Notification Settings
      _notificationSettings = allSettings.notifications;
    });

    // 3. Auto-reschedule if we just gained permission
    if (!previousPermission && _permissionStatus.hasNotificationPermission) {
      if (_notificationSettings.enabled) {
        debugPrint('SettingsScreen: Permission granted on resume - Auto rescheduling');
        _rescheduleNotifications();
      }
    }
  }

  void _rescheduleNotifications() {
    if (!_notificationSettings.enabled || !_permissionStatus.hasNotificationPermission) {
      debugPrint('SettingsScreen: Reschedule aborted. Enabled=${_notificationSettings.enabled}, Perm=${_permissionStatus.hasNotificationPermission}');
      _notificationService.cancelAllNotifications();
      NotificationService().cancelAll();
      return;
    }

    final langService = Provider.of<LanguageService>(context, listen: false);
    final traditionService = Provider.of<TraditionService>(context, listen: false);
    final currentTradition = traditionService.currentTradition;
    final currentLang = langService.currentLocale.languageCode;
    final baseTexts = langService.localizedStrings;

    Future.microtask(() async {
      try {
        // Update native notification service settings
        await _notificationService.updateSettings(NotificationSettings(
          enabled: _notificationSettings.enabled,
          remind2Days: _notificationSettings.remind2Days,
          remind1Day: _notificationSettings.remind1Day,
          remindOnStart: _notificationSettings.remindOnStart,
          remindOnParana: _notificationSettings.remindOnParana,
        ));

        // Use unified TraditionNotificationCoordinator
        await TraditionNotificationCoordinator.rescheduleForTradition(
          tradition: currentTradition,
          languageCode: currentLang,
          timezone: _currentTimezone,
          baseTexts: baseTexts,
          remind1Day: _notificationSettings.remind1Day,
          remind2Days: _notificationSettings.remind2Days,
          remindOnDay: _notificationSettings.remindOnStart,
          remindOnParana: _notificationSettings.remindOnParana,
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
      await NotificationService().cancelAll();
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

  Future<void> _openCityPicker() async {
    final loc = await CityPickerDialog.show(
      context,
      currentLocation: _currentLocation,
    );
    if (loc != null && mounted) {
      final auto = await NativeLocationService().isAutoDetectEnabled();
      setState(() {
        _currentLocation = loc;
        _currentTimezone = loc.timezone;
        _isAutoDetect = auto;
      });
      _rescheduleNotifications();
    }
  }

  Future<void> _toggleAutoDetectLocation(bool value) async {
    final locService = NativeLocationService();
    await locService.setAutoDetectEnabled(value);
    if (value) {
      final loc = await locService.getCurrentLocation();
      if (loc != null && mounted) {
        setState(() {
          _currentLocation = loc;
          _currentTimezone = loc.timezone;
          _isAutoDetect = true;
        });
        _rescheduleNotifications();
      }
    } else {
      if (mounted) {
        setState(() => _isAutoDetect = false);
      }
    }
  }

  void _showLanguageSelectionDialog(LanguageService langService) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(langService.translate('language')),
        children: [
          SimpleDialogOption(
            onPressed: () {
              langService.changeLanguage('en');
              Navigator.pop(ctx);
              _rescheduleNotifications();
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('English', style: TextStyle(fontSize: 16)),
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              langService.changeLanguage('hi');
              Navigator.pop(ctx);
              _rescheduleNotifications();
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('हिंदी (Hindi)', style: TextStyle(fontSize: 16)),
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              langService.changeLanguage('ta');
              Navigator.pop(ctx);
              _rescheduleNotifications();
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('தமிழ் (Tamil)', style: TextStyle(fontSize: 16)),
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              langService.changeLanguage('te');
              Navigator.pop(ctx);
              _rescheduleNotifications();
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('తెలుగు (Telugu)', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);

    final bool togglesEnabled = _permissionStatus.hasNotificationPermission &&
        _notificationSettings.enabled;

    // Show permissions section always on Android (since USE_EXACT_ALARM is auto-granted)
    final bool showPermissionsSection = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator(color: tealColor));
    }

    String todaySunrise = '';
    if (_currentLocation != null) {
      try {
        final rise = PanchangCalculator.calculateSunrise(
          latitude: _currentLocation!.latitude,
          longitude: _currentLocation!.longitude,
          date: DateTime.now(),
        );
        if (rise != null) {
          todaySunrise = DateFormat('hh:mm a').format(rise);
        }
      } catch (_) {}
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ==================== LOCATION ====================
        Text(lang.translate('location_settings'),
            style: const TextStyle(color: tealColor, fontWeight: FontWeight.bold)),
        SwitchListTile(
          title: Text(lang.translate('current_location')),
          subtitle: Text(
            _isAutoDetect
                ? 'GPS auto-detection enabled'
                : 'Using manually selected city',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          value: _isAutoDetect,
          activeColor: tealColor,
          onChanged: _toggleAutoDetectLocation,
        ),
        ListTile(
          leading: const Icon(Icons.location_city, color: tealColor),
          title: Text(_currentLocation?.displayName ?? _currentLocation?.city ?? 'Select City'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_currentLocation != null) ...[
                Text(
                  '${_currentLocation!.latitude.toStringAsFixed(2)}°N, ${_currentLocation!.longitude.toStringAsFixed(2)}°E • $_currentTimezone',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (todaySunrise.isNotEmpty)
                  Text(
                    '${lang.translate('sunrise_time')}: $todaySunrise',
                    style: const TextStyle(fontSize: 12, color: tealColor, fontWeight: FontWeight.w500),
                  ),
              ],
            ],
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: _openCityPicker,
        ),
        const Divider(),

        // ==================== LANGUAGE ====================
        Text(lang.translate('language'),
            style: const TextStyle(color: tealColor, fontWeight: FontWeight.bold)),
        ListTile(
          leading: const Icon(Icons.language, color: tealColor),
          title: Text(lang.translate('language')),
          subtitle: Text(
            lang.currentLocale.languageCode == 'ta'
                ? 'தமிழ்'
                : (lang.currentLocale.languageCode == 'te'
                    ? 'తెలుగు'
                    : (lang.currentLocale.languageCode == 'hi' ? 'हिंदी' : 'English')),
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: () => _showLanguageSelectionDialog(lang),
        ),
        const Divider(),

        // ==================== TRADITION ====================
        Text(lang.translate('tradition_settings_title'),
            style: const TextStyle(color: tealColor, fontWeight: FontWeight.bold)),
        Consumer<TraditionService>(
          builder: (context, traditionService, _) {
            final currentTradition = traditionService.currentTradition;
            String traditionName;
            switch (currentTradition) {
              case AppTradition.smarta:
                traditionName = lang.translate('tradition_smarta');
                break;
              case AppTradition.vaishnava:
                traditionName = lang.translate('tradition_vaishnava');
                break;
              case AppTradition.general:
                traditionName = lang.translate('tradition_general');
                break;
            }

            return Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.brightness_medium_outlined, color: tealColor),
                  title: Text(lang.translate('tradition')),
                  subtitle: Text(
                    traditionName,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () => _showTraditionSelectionDialog(traditionService, lang),
                ),
                ListTile(
                  leading: const Icon(Icons.restaurant_menu, color: tealColor),
                  title: Text(lang.translate('food_guide_title')),
                  subtitle: Text(
                    lang.translate('food_guide_desc'),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FoodGuideScreen()),
                    );
                  },
                ),
              ],
            );
          },
        ),
        const Divider(),

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

        // Remind on Parana (breaking fast)
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
                final traditionService = Provider.of<TraditionService>(context, listen: false);
                final tag = TraditionNotificationHelper.getTraditionTag(
                  traditionService.currentTradition,
                  langService.currentLocale.languageCode,
                );
                final rawTitle = langService.translate('test_notif_title');
                final title = (tag.isNotEmpty && !rawTitle.startsWith('['))
                    ? '$tag $rawTitle'
                    : rawTitle;

                await _notificationService.showTestNotification(
                  title,
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

          Text(lang.translate('permissions'),
              style: const TextStyle(color: tealColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          _buildPermissionRow(
            icon: Icons.settings_applications,
            iconColor: tealColor,
            title: lang.translate('app_settings'),
            showButton: true,
            buttonText: lang.translate('settings_button'),
            onTap: () => _settingsService.openAppSettings(),
            onInfoTap: _showPermissionsGuideDialog,
          ),
        ],

        const Divider(height: 32),

        // ==================== ABOUT ====================
        Text(lang.translate('about'),
            style: const TextStyle(color: tealColor, fontWeight: FontWeight.bold)),
        ListTile(
          leading: const Icon(Icons.star_rate_rounded, color: tealColor),
          title: Text(lang.translate('rate_app')),
          subtitle: Text(lang.translate('rate_app_desc'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
          onTap: () => _settingsService.openStoreListing(),
        ),
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
          trailing: const Text("1.1.1", style: TextStyle(color: Colors.grey)),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tealColor.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tealColor.withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_outlined, size: 18, color: tealColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lang.translate('religious_disclaimer_title'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: tealColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                lang.translate('religious_disclaimer_text'),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade300
                      : Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
    required bool showButton,
    required String buttonText,
    VoidCallback? onTap,
    VoidCallback? onInfoTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
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

  void _showPermissionsGuideDialog() {
    final lang = Provider.of<LanguageService>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.settings_applications, color: tealColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                lang.translate('perm_guide_title'),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            lang.translate('perm_guide_desc'),
            style: const TextStyle(fontSize: 14),
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

  void _showTraditionSelectionDialog(TraditionService traditionService, LanguageService lang) {
    showDialog(
      context: context,
      builder: (ctx) {
        AppTradition selected = traditionService.currentTradition;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(lang.translate('choose_tradition')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<AppTradition>(
                      title: Text(lang.translate('tradition_general')),
                      subtitle: Text(
                        lang.translate('tradition_general_desc'),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      value: AppTradition.general,
                      groupValue: selected,
                      activeColor: tealColor,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selected = val);
                        }
                      },
                    ),
                    RadioListTile<AppTradition>(
                      title: Text(lang.translate('tradition_smarta')),
                      subtitle: Text(
                        lang.translate('tradition_smarta_desc'),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      value: AppTradition.smarta,
                      groupValue: selected,
                      activeColor: tealColor,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selected = val);
                        }
                      },
                    ),
                    RadioListTile<AppTradition>(
                      title: Text(lang.translate('tradition_vaishnava')),
                      subtitle: Text(
                        lang.translate('tradition_vaishnava_desc'),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      value: AppTradition.vaishnava,
                      groupValue: selected,
                      activeColor: tealColor,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selected = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(lang.translate('cancel'), style: const TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await traditionService.setTradition(selected);
                    _ekadashiService.clearCache();
                    _rescheduleNotifications();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: tealColor),
                  child: Text(lang.translate('save'), style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}