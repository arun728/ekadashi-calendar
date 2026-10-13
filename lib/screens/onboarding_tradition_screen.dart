import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/tradition_service.dart';
import '../services/language_service.dart';
import '../main.dart';

class OnboardingTraditionScreen extends StatefulWidget {
  final bool isModal;

  const OnboardingTraditionScreen({super.key, this.isModal = false});

  @override
  State<OnboardingTraditionScreen> createState() => _OnboardingTraditionScreenState();
}

class _OnboardingTraditionScreenState extends State<OnboardingTraditionScreen> {
  AppTradition _selectedTradition = AppTradition.general;
  static const Color tealColor = Color(0xFF00A19B);

  @override
  void initState() {
    super.initState();
    final traditionService = Provider.of<TraditionService>(context, listen: false);
    _selectedTradition = traditionService.currentTradition;
  }

  Future<void> _handleContinue() async {
    final traditionService = Provider.of<TraditionService>(context, listen: false);
    await traditionService.completeOnboarding(_selectedTradition);

    if (!mounted) return;

    if (widget.isModal) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    }
  }

  Future<void> _handleSkip() async {
    // Default to General on skip
    final traditionService = Provider.of<TraditionService>(context, listen: false);
    await traditionService.completeOnboarding(AppTradition.general);

    if (!mounted) return;

    if (widget.isModal) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.translate('app_title')),
        centerTitle: true,
        actions: [
          if (!widget.isModal)
            TextButton(
              onPressed: _handleSkip,
              child: Text(
                lang.translate('skip_button'),
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              // Header Title
              Text(
                lang.translate('choose_tradition'),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              // Subtitle
              Text(
                lang.translate('choose_tradition_subtitle'),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              // Options
              Expanded(
                child: ListView(
                  children: [
                    _buildTraditionOption(
                      tradition: AppTradition.general,
                      title: lang.translate('tradition_general'),
                      description: lang.translate('tradition_general_desc'),
                      icon: Icons.public,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildTraditionOption(
                      tradition: AppTradition.smarta,
                      title: lang.translate('tradition_smarta'),
                      description: lang.translate('tradition_smarta_desc'),
                      icon: Icons.brightness_6_outlined,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildTraditionOption(
                      tradition: AppTradition.vaishnava,
                      title: lang.translate('tradition_vaishnava'),
                      description: lang.translate('tradition_vaishnava_desc'),
                      icon: Icons.spa_outlined,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),

              // Continue Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tealColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    lang.translate('continue_button'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTraditionOption({
    required AppTradition tradition,
    required String title,
    required String description,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _selectedTradition == tradition;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedTradition = tradition;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? tealColor.withOpacity(0.12)
              : (isDark ? const Color(0xFF1F1F1F) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? tealColor : (isDark ? Colors.white12 : Colors.grey.shade300),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? tealColor : (isDark ? Colors.white10 : Colors.grey.shade100),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? tealColor
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      Radio<AppTradition>(
                        value: tradition,
                        groupValue: _selectedTradition,
                        activeColor: tealColor,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedTradition = value);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black54,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
