# Privacy Policy for Ekadashi Calendar

**Last Updated:** January 30, 2026  
**Developer:** Arun Kumar MP  
**Contact:** arunmp.728@gmail.com

## Overview
Ekadashi Calendar ("the App") is committed to protecting your privacy. This app is designed with privacy-first principles and collects minimal data, all stored locally on your device.

## Data Collection

### Location Data (Optional)
- **What we collect:** GPS coordinates, city name, timezone
- **Why we collect it:** To automatically detect your timezone and display accurate Ekadashi fasting times for your location. The app provides different fasting times for IST, EST, CST, MST, and PST timezones.
- **How we use it:** Location is used only to determine your timezone. 
- **If you deny location permission:** The app automatically uses your device's system timezone (from Android settings) to determine the correct timezone data to display. For example, if your Android timezone is set to "America/New_York", the app will show EST times.
- **Storage:** All location data is stored locally on your device in encrypted SharedPreferences
- **Retention:** Cached for 5 minutes for performance, then refreshed on next app use
- **No tracking:** We never track your location history or movement

### User Preferences (Local Storage Only)
- Language selection (English, Hindi, Tamil)
- Theme preference (Light/Dark mode)
- Notification settings
- Timezone (detected from location or system timezone)
- All stored locally on your device

### Notification Data
- Scheduled reminder times for Ekadashi dates
- Notification preferences (which types of reminders you want)
- Stored locally using Android WorkManager

## Data We Do NOT Collect
- ❌ No user accounts or personal information
- ❌ No email addresses or phone numbers
- ❌ No location tracking or movement history
- ❌ No analytics or usage statistics
- ❌ No device identifiers for tracking
- ❌ No advertising IDs

## Data Storage and Security
- **100% Local Storage:** All data is stored on your device only
- **No Cloud Sync:** We do not sync data to any servers
- **No External Servers:** The app works completely offline
- **Encryption:** Data is stored in Android's secure SharedPreferences
- **Data Deletion:** Uninstalling the app deletes all stored data

## Data Sharing
- **Zero Third-Party Sharing:** We do not share any data with third parties
- **No Analytics Services:** We do not use Firebase, Google Analytics, or any tracking services
- **No Advertising Networks:** This app is 100% ad-free
- **Share Feature:** When you use the "Share" button, only the Ekadashi text you explicitly choose to share leaves your device (via your chosen app like WhatsApp, Email, etc.)

## Permissions Explained

### Location Permission (Optional)
- **Why:** To automatically detect your timezone for accurate fasting times
- **Required:** No - app uses your device's system timezone if you deny this permission
- **Fallback:** If denied, app reads Android's system timezone setting to determine which timezone data (IST/EST/CST/MST/PST) to display

### Notification Permission
- **Why:** To send you Ekadashi fasting reminders
- **Required:** No - app works without notifications, but you'll miss reminders

### Exact Alarm Permission (SCHEDULE_EXACT_ALARM / USE_EXACT_ALARM)
- **Why:** Hindu fasting times are based on precise astronomical calculations (sunrise times). Ekadashi fasting must begin and end at exact times according to the Hindu Panchang. Inexact alarms could cause notifications to arrive minutes or hours late, resulting in devotees starting or breaking their fast at spiritually incorrect times.
- **How we use it:** To schedule notifications at the exact sunrise time (fasting start) and exact parana window (break-fast time) as calculated per Hindu calendar tradition
- **Required:** No - but highly recommended for devotees who rely on precise spiritual timing
- **Note:** This permission does not allow the app to wake your device excessively or drain battery. We only use it for the 2-4 notifications per Ekadashi that you've explicitly enabled.

## Children's Privacy
This app does not knowingly collect any data from children under 13. The app is designed for general spiritual use and does not target children specifically.

## Changes to Privacy Policy
We may update this privacy policy to reflect changes in the app. We will notify users of any material changes by updating the "Last Updated" date.

## Your Rights
You can:
- View all locally stored data in Settings
- Delete all data by clearing app storage or uninstalling
- Deny location permission and rely on system timezone fallback
- Disable all notifications in settings
- Change language and theme preferences anytime

## Contact
For privacy questions or concerns:
- **Email:** arunmp.728@gmail.com
- **Developer:** Arun Kumar MP
- **App:** Ekadashi Calendar

## Compliance
This app complies with:
- Google Play Developer Policy
- Android's data safety requirements
- GDPR principles (data minimization, local storage, user control)
