import 'package:flutter/material.dart';

/// Observance status for an Ekadashi
enum ObservanceStatus {
  unrecorded,
  observed,
  partial,
  missed;

  String get key => name;

  static ObservanceStatus fromString(String? value) {
    if (value == null) return ObservanceStatus.unrecorded;
    return ObservanceStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ObservanceStatus.unrecorded,
    );
  }
}

/// Fasting method used during observance
enum FastingMethod {
  fullFast,
  waterOnly,
  fruitsMilk,
  oneMeal,
  other;

  String get key => name;

  static FastingMethod? fromString(String? value) {
    if (value == null || value.isEmpty) return null;
    return FastingMethod.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => FastingMethod.other,
    );
  }
}

/// A private devotional record of an Ekadashi observance.
/// Kept completely separate from the original Ekadashi calendar occurrence.
class VratHistory {
  final String id;
  final String localProfileId;
  final int ekadashiOccurrenceId;
  final String? occurrenceUid;
  final String ekadashiDate; // YYYY-MM-DD
  final String ekadashiName;
  final ObservanceStatus status;
  final FastingMethod? fastingMethod;
  final String? fastingMethodOther;
  final String? note;
  final String recordedAtUTC;
  final String updatedAtUTC;
  final String? tradition;
  final String? timezone;
  final String? locationContext;

  const VratHistory({
    required this.id,
    this.localProfileId = 'default',
    required this.ekadashiOccurrenceId,
    this.occurrenceUid,
    required this.ekadashiDate,
    required this.ekadashiName,
    required this.status,
    this.fastingMethod,
    this.fastingMethodOther,
    this.note,
    required this.recordedAtUTC,
    required this.updatedAtUTC,
    this.tradition,
    this.timezone,
    this.locationContext,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'localProfileId': localProfileId,
    'ekadashiOccurrenceId': ekadashiOccurrenceId,
    'occurrenceUid': occurrenceUid,
    'ekadashiDate': ekadashiDate,
    'ekadashiName': ekadashiName,
    'status': status.name,
    'fastingMethod': fastingMethod?.name,
    'fastingMethodOther': fastingMethodOther,
    'note': note,
    'recordedAtUTC': recordedAtUTC,
    'updatedAtUTC': updatedAtUTC,
    'tradition': tradition,
    'timezone': timezone,
    'locationContext': locationContext,
  };

  factory VratHistory.fromJson(Map<String, dynamic> json) {
    return VratHistory(
      id: json['id'] as String? ?? '',
      localProfileId: json['localProfileId'] as String? ?? 'default',
      ekadashiOccurrenceId: json['ekadashiOccurrenceId'] as int? ?? 0,
      occurrenceUid: json['occurrenceUid'] as String?,
      ekadashiDate: json['ekadashiDate'] as String? ?? '',
      ekadashiName: json['ekadashiName'] as String? ?? '',
      status: ObservanceStatus.fromString(json['status'] as String?),
      fastingMethod: FastingMethod.fromString(json['fastingMethod'] as String?),
      fastingMethodOther: json['fastingMethodOther'] as String?,
      note: json['note'] as String?,
      recordedAtUTC:
          json['recordedAtUTC'] as String? ??
          DateTime.now().toUtc().toIso8601String(),
      updatedAtUTC:
          json['updatedAtUTC'] as String? ??
          DateTime.now().toUtc().toIso8601String(),
      tradition: json['tradition'] as String?,
      timezone: json['timezone'] as String?,
      locationContext: json['locationContext'] as String?,
    );
  }

  VratHistory copyWith({
    String? id,
    String? localProfileId,
    int? ekadashiOccurrenceId,
    String? occurrenceUid,
    String? ekadashiDate,
    String? ekadashiName,
    ObservanceStatus? status,
    FastingMethod? fastingMethod,
    String? fastingMethodOther,
    String? note,
    String? recordedAtUTC,
    String? updatedAtUTC,
    String? tradition,
    String? timezone,
    String? locationContext,
  }) {
    return VratHistory(
      id: id ?? this.id,
      localProfileId: localProfileId ?? this.localProfileId,
      ekadashiOccurrenceId: ekadashiOccurrenceId ?? this.ekadashiOccurrenceId,
      occurrenceUid: occurrenceUid ?? this.occurrenceUid,
      ekadashiDate: ekadashiDate ?? this.ekadashiDate,
      ekadashiName: ekadashiName ?? this.ekadashiName,
      status: status ?? this.status,
      fastingMethod: fastingMethod ?? this.fastingMethod,
      fastingMethodOther: fastingMethodOther ?? this.fastingMethodOther,
      note: note ?? this.note,
      recordedAtUTC: recordedAtUTC ?? this.recordedAtUTC,
      updatedAtUTC: updatedAtUTC ?? this.updatedAtUTC,
      tradition: tradition ?? this.tradition,
      timezone: timezone ?? this.timezone,
      locationContext: locationContext ?? this.locationContext,
    );
  }
}

/// Definition of an Achievement milestone
class Achievement {
  final String id;
  final String key;
  final String titleKey;
  final String descriptionKey;
  final String conditionType; // 'count' | 'streak' | 'annual_full'
  final int targetValue;
  final IconData icon;
  final int sortOrder;

  const Achievement({
    required this.id,
    required this.key,
    required this.titleKey,
    required this.descriptionKey,
    required this.conditionType,
    required this.targetValue,
    required this.icon,
    required this.sortOrder,
  });
}

/// Progress and unlock record of a user milestone
class UserAchievement {
  final String id;
  final String localProfileId;
  final String achievementId;
  final int progressValue;
  final bool isUnlocked;
  final String? unlockedAtUTC;
  final String lastEvaluatedAtUTC;

  const UserAchievement({
    required this.id,
    this.localProfileId = 'default',
    required this.achievementId,
    required this.progressValue,
    required this.isUnlocked,
    this.unlockedAtUTC,
    required this.lastEvaluatedAtUTC,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'localProfileId': localProfileId,
    'achievementId': achievementId,
    'progressValue': progressValue,
    'isUnlocked': isUnlocked,
    'unlockedAtUTC': unlockedAtUTC,
    'lastEvaluatedAtUTC': lastEvaluatedAtUTC,
  };

  factory UserAchievement.fromJson(Map<String, dynamic> json) {
    return UserAchievement(
      id: json['id'] as String? ?? '',
      localProfileId: json['localProfileId'] as String? ?? 'default',
      achievementId: json['achievementId'] as String? ?? '',
      progressValue: json['progressValue'] as int? ?? 0,
      isUnlocked: json['isUnlocked'] as bool? ?? false,
      unlockedAtUTC: json['unlockedAtUTC'] as String?,
      lastEvaluatedAtUTC:
          json['lastEvaluatedAtUTC'] as String? ??
          DateTime.now().toUtc().toIso8601String(),
    );
  }

  UserAchievement copyWith({
    String? id,
    String? localProfileId,
    String? achievementId,
    int? progressValue,
    bool? isUnlocked,
    String? unlockedAtUTC,
    String? lastEvaluatedAtUTC,
  }) {
    return UserAchievement(
      id: id ?? this.id,
      localProfileId: localProfileId ?? this.localProfileId,
      achievementId: achievementId ?? this.achievementId,
      progressValue: progressValue ?? this.progressValue,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAtUTC: unlockedAtUTC ?? this.unlockedAtUTC,
      lastEvaluatedAtUTC: lastEvaluatedAtUTC ?? this.lastEvaluatedAtUTC,
    );
  }
}

/// Summary statistics for a specific year
class VratYearStats {
  final int year;
  final int totalOccurrences;
  final int observedCount;
  final int partialCount;
  final int missedCount;
  final int unrecordedCount;
  final double completionPercentage;

  const VratYearStats({
    required this.year,
    required this.totalOccurrences,
    required this.observedCount,
    required this.partialCount,
    required this.missedCount,
    required this.unrecordedCount,
    required this.completionPercentage,
  });
}
