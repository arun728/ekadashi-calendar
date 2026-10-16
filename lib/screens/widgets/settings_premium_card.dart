import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_language.dart';
import '../../services/language_service.dart';
import '../../services/play_billing_service.dart';
import '../../services/premium_service.dart';
import '../../widgets/glass_tube.dart';
import '../../widgets/settings_group.dart';
import '../premium_screen.dart';
import '../../widgets/app_icons.dart';

/// Premium at the top of Settings (docs/ROADMAP.md Phase 5), like the iOS
/// SettingsPremiumCard: what it unlocks and the Google Play prices, or the
/// member's plan with Manage and Change plan.
class SettingsPremiumCard extends StatelessWidget {
  const SettingsPremiumCard({super.key, this.currentTimezone = 'IST'});
  final String currentTimezone;

  /// iOS Theme.amber and .orange (the crown's gradient).
  static const _amber = Color(0xFFFFC208);
  static const _orange = Color(0xFFFF9500);

  /// A capsule button with a white label, like the iOS glassProminent one.
  static ButtonStyle get _prominent => FilledButton.styleFrom(
    backgroundColor: GlassTubeColors.teal,
    foregroundColor: Colors.white,
    shape: const StadiumBorder(),
    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
  );

  /// The iOS headline label (merged with the button's own font).
  static const _label = TextStyle(fontSize: 17, fontWeight: FontWeight.w600);

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
                alignment: Alignment.center,
                child: const _PremiumMark(
                  size: 26,
                  top: _amber,
                  bottom: _orange,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.translate('premium_title'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: SettingsStyle.primary(context),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      lang.translate(subtitle),
                      style: TextStyle(
                        fontSize: 15,
                        color: SettingsStyle.secondary(context),
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
          const Icon(
            AppIcons.premiumCalendar,
            size: 24,
            color: GlassTubeColors.teal,
          ),
          lang.translate('premium_feature_calendar'),
        ),
        _benefit(
          context,
          const Icon(
            AppIcons.premiumVrat,
            size: 24,
            color: GlassTubeColors.teal,
          ),
          lang.translate('premium_feature_vrat'),
        ),
        _benefit(
          context,
          const Icon(
            AppIcons.premiumPanchang,
            size: 24,
            color: GlassTubeColors.teal,
          ),
          lang.translate('premium_feature_panchang_v2'),
        ),
        if (monthly != null && lifetime != null)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              AppStrings.translateWithArgs(
                'settings_premium_from',
                lang.currentLocale.languageCode,
                [monthly, lifetime],
              ),
              key: const Key('settings_premium_prices'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: SettingsStyle.primary(context),
              ),
            ),
          ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('settings_premium'),
            style: _prominent,
            onPressed: () =>
                openPremium(context, currentTimezone: currentTimezone),
            child: Text(lang.translate('settings_premium_cta'), style: _label),
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
          Text(
            lang.translate('premium_lifetime_thanks_body'),
            style: const TextStyle(fontSize: 15),
          )
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
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          const SizedBox(height: 4),
          Text(
            lang.translate(
              premium.subscriptionCancelled
                  ? 'premium_cancelled_body'
                  : 'premium_subscriber_body',
            ),
            style: TextStyle(
              fontSize: 13,
              color: SettingsStyle.secondary(context),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            if (premium.subscribed) ...[
              Expanded(
                child: OutlinedButton(
                  key: const Key('settings_premium_manage'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GlassTubeColors.teal,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    side: BorderSide(
                      color: GlassTubeColors.teal.withValues(alpha: .5),
                    ),
                  ),
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
                  style: _prominent.copyWith(
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                  onPressed: () =>
                      openPremium(context, currentTimezone: currentTimezone),
                  child: Text(
                    lang.translate('settings_premium_plans'),
                    style: _label,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// A teal icon and its line, like the iOS Label.
  Widget _benefit(BuildContext context, Widget icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        SizedBox(width: 30, child: Center(child: icon)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              color: SettingsStyle.primary(context),
            ),
          ),
        ),
      ],
    ),
  );
}

/// The Premium symbol (AppIcons.premium, as on iOS) with a top-to-bottom
/// amber to orange gradient.
class _PremiumMark extends StatelessWidget {
  const _PremiumMark({
    required this.size,
    required this.top,
    required this.bottom,
  });
  final double size;
  final Color top, bottom;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: (bounds) => LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [top, bottom],
    ).createShader(bounds),
    child: Icon(AppIcons.premium, size: size, color: top),
  );
}
