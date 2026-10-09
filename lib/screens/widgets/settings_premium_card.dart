import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_language.dart';
import '../../services/language_service.dart';
import '../../services/play_billing_service.dart';
import '../../services/premium_service.dart';
import '../../widgets/glass_tube.dart';
import '../premium_screen.dart';

/// Premium at the top of Settings (docs/ROADMAP.md Phase 5), like the iOS
/// SettingsPremiumCard: what it unlocks and the Google Play prices, or the
/// member's plan with Manage and Change plan.
class SettingsPremiumCard extends StatelessWidget {
  const SettingsPremiumCard({super.key, this.currentTimezone = 'IST'});
  final String currentTimezone;

  static const _amber = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    final premium = context.watch<PremiumService?>();
    final billing = context.watch<PlayBillingService?>();
    final member = premium?.isPremium ?? false;
    final subtitle = premium?.lifetime == true
        ? 'premium_lifetime_thanks_title'
        : premium?.subscribed == true
        ? (premium!.subscriptionCancelled
              ? 'premium_cancelled_title'
              : 'premium_subscriber_title')
        : 'settings_premium_subtitle';
    return Container(
      key: const Key('settings_premium_card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            GlassTubeColors.teal.withValues(alpha: .45),
            GlassTubeColors.teal.withValues(alpha: .12),
          ],
        ),
        border: Border.all(
          color: GlassTubeColors.foreground(context).withValues(alpha: .14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _amber.withValues(alpha: .18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  color: _amber,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.translate('premium_title'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lang.translate(subtitle),
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (member)
            _member(context, lang, premium!)
          else
            _offer(context, lang, billing),
        ],
      ),
    );
  }

  Widget _offer(
    BuildContext context,
    LanguageService lang,
    PlayBillingService? billing,
  ) {
    String? price(String id) =>
        billing?.plans.where((p) => p.id == id).firstOrNull?.price;
    final monthly = price('monthly'), lifetime = price('lifetime');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _benefit(
          context,
          Icons.event_available,
          lang.translate('premium_feature_calendar'),
        ),
        _benefit(context, Icons.spa, lang.translate('premium_feature_vrat')),
        _benefit(
          context,
          Icons.auto_awesome,
          lang.translate('premium_feature_panchang_v2'),
        ),
        if (monthly != null && lifetime != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              AppStrings.translateWithArgs(
                'settings_premium_from',
                lang.currentLocale.languageCode,
                [monthly, lifetime],
              ),
              key: const Key('settings_premium_prices'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('settings_premium'),
            style: FilledButton.styleFrom(
              backgroundColor: GlassTubeColors.teal,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () =>
                openPremium(context, currentTimezone: currentTimezone),
            child: Text(
              lang.translate('settings_premium_cta'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _member(
    BuildContext context,
    LanguageService lang,
    PremiumService premium,
  ) {
    final plan = context.watch<PlayBillingService?>()?.currentPlanId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (premium.lifetime)
          Text(lang.translate('premium_lifetime_thanks_body'))
        else ...[
          if (plan != null)
            Text(
              AppStrings.translateWithArgs(
                'settings_premium_plan',
                lang.currentLocale.languageCode,
                [
                  lang.translate(
                    plan == 'yearly' ? 'premium_yearly' : 'premium_monthly',
                  ),
                ],
              ),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          Text(
            lang.translate(
              premium.subscriptionCancelled
                  ? 'premium_cancelled_body'
                  : 'premium_subscriber_body',
            ),
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            if (premium.subscribed) ...[
              Expanded(
                child: OutlinedButton(
                  key: const Key('settings_premium_manage'),
                  onPressed: () => launchUrl(
                    Uri.https(
                      'play.google.com',
                      '/store/account/subscriptions',
                      {
                        'package': 'com.applausestudios.ekadashi_calendar',
                        'sku': PlayBillingService.subscription,
                      },
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Text(lang.translate('settings_premium_manage')),
                ),
              ),
              const SizedBox(width: 10),
            ],
            if (!premium.lifetime)
              Expanded(
                child: FilledButton(
                  key: const Key('settings_premium'),
                  style: FilledButton.styleFrom(
                    backgroundColor: GlassTubeColors.teal,
                  ),
                  onPressed: () =>
                      openPremium(context, currentTimezone: currentTimezone),
                  child: Text(lang.translate('settings_premium_plans')),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _benefit(BuildContext context, IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: GlassTubeColors.teal),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    ),
  );
}
