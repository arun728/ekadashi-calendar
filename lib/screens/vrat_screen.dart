import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ekadashi_service.dart';
import '../services/language_service.dart';
import 'details_screen.dart';

/// Vrat Tracker & Achievement System Screen
/// Accessible via the "Vrat" bottom navigation tab.
class VratScreen extends StatefulWidget {
  final List<EkadashiDate> ekadashiList;
  final String? currentTimezone;

  const VratScreen({
    super.key,
    required this.ekadashiList,
    this.currentTimezone,
  });

  @override
  State<VratScreen> createState() => _VratScreenState();
}

class _VratScreenState extends State<VratScreen> {
  static const Color _tealColor = Color(0xFF00A19B);
  static const Color _goldColor = Color(0xFFFFB300);

  final Set<String> _observedVrats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVratData();
  }

  Future<void> _loadVratData() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('observed_vrats') ?? [];
    if (mounted) {
      setState(() {
        _observedVrats.clear();
        _observedVrats.addAll(saved);
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleVrat(String ekadashiId) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_observedVrats.contains(ekadashiId)) {
        _observedVrats.remove(ekadashiId);
      } else {
        _observedVrats.add(ekadashiId);
      }
    });
    await prefs.setStringList('observed_vrats', _observedVrats.toList());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = Provider.of<LanguageService>(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _tealColor));
    }

    final totalVrats = widget.ekadashiList.length;
    final completedCount = _observedVrats.length;
    final progress = totalVrats > 0 ? (completedCount / totalVrats).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade100,
      appBar: AppBar(
        title: Text(lang.translate('vrat')),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // 1. Vrat Tracker Progress Card
          _buildProgressCard(completedCount, totalVrats, progress, isDark),

          const SizedBox(height: 20),

          // 2. Achievement System Section
          _buildSectionHeader('Spiritual Achievements', Icons.military_tech_outlined, isDark),
          const SizedBox(height: 12),
          _buildAchievementsGrid(completedCount, isDark),

          const SizedBox(height: 24),

          // 3. Ekadashi Vrat Observance Log
          _buildSectionHeader('Ekadashi Fasting Log', Icons.check_circle_outline, isDark),
          const SizedBox(height: 12),
          _buildVratLogList(isDark),

          const SizedBox(height: 24),

          // 4. Fasting Rules & Discipline Guide
          _buildSectionHeader('Vrat Disciplines & Guidelines', Icons.rule, isDark),
          const SizedBox(height: 12),
          _buildDisciplineCard(isDark),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, color: _tealColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard(int completed, int total, double progress, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Annual Fasting Journey',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$completed of $total Ekadashis observed',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _tealColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    color: _tealColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(_tealColor),
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsGrid(int completed, bool isDark) {
    final achievements = [
      _Achievement(
        title: 'Sankalpa',
        description: 'Record your first fast',
        icon: Icons.spa,
        unlocked: completed >= 1,
      ),
      _Achievement(
        title: 'Parana Keeper',
        description: 'Complete 3 fasts',
        icon: Icons.wb_sunny_outlined,
        unlocked: completed >= 3,
      ),
      _Achievement(
        title: 'Paksha Devotee',
        description: 'Complete 6 fasts',
        icon: Icons.brightness_6,
        unlocked: completed >= 6,
      ),
      _Achievement(
        title: 'Maha Vratam',
        description: 'Complete 12 fasts',
        icon: Icons.workspace_premium,
        unlocked: completed >= 12,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemCount: achievements.length,
      itemBuilder: (context, index) {
        final a = achievements[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: a.unlocked ? _tealColor.withValues(alpha: 0.5) : (isDark ? Colors.white10 : Colors.black12),
              width: a.unlocked ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: a.unlocked ? _goldColor.withValues(alpha: 0.2) : (isDark ? Colors.white10 : Colors.grey.shade200),
                ),
                child: Icon(
                  a.icon,
                  color: a.unlocked ? _goldColor : Colors.grey,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      a.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: a.unlocked ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      a.description,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVratLogList(bool isDark) {
    if (widget.ekadashiList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('No Ekadashi dates available'),
      );
    }

    final items = widget.ekadashiList.take(6).toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: items.map((e) {
          final isChecked = _observedVrats.contains(e.id.toString());
          return ListTile(
            leading: Checkbox(
              value: isChecked,
              activeColor: _tealColor,
              onChanged: (_) => _toggleVrat(e.id.toString()),
            ),
            title: Text(
              e.name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                decoration: isChecked ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Text(
              '${e.date.day}/${e.date.month}/${e.date.year} • ${e.paksha.isNotEmpty ? e.paksha : "Krishna"}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 14),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailsScreen(
                      ekadashi: e,
                      timezone: widget.currentTimezone,
                    ),
                  ),
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDisciplineCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDisciplineRow(
            '1. Dashami (Day Before)',
            'Consume light vegetarian sattvic food. Avoid grains and heavy meals after sunset.',
            isDark,
          ),
          const Divider(height: 20),
          _buildDisciplineRow(
            '2. Ekadashi (Fasting Day)',
            'Fast completely (Nirjala) or consume water, milk, and permissible fruits. Chanting & meditation.',
            isDark,
          ),
          const Divider(height: 20),
          _buildDisciplineRow(
            '3. Dvadashi (Parana Day)',
            'Break the fast strictly within the auspicious Parana time window after sunrise.',
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildDisciplineRow(String title, String desc, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13.5,
            color: _tealColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          desc,
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _Achievement {
  final String title;
  final String description;
  final IconData icon;
  final bool unlocked;

  _Achievement({
    required this.title,
    required this.description,
    required this.icon,
    required this.unlocked,
  });
}
