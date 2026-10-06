import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/language_service.dart';
import '../services/premium_service.dart';
import '../services/play_billing_service.dart';

Future<void> openPremium(
  BuildContext context, {
  String currentTimezone = 'IST',
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => PremiumScreen(currentTimezone: currentTimezone),
  ),
);

/// Paywall. Premium is bought and restored through Google Play only; no
/// Google sign-in, server account or rewards are involved in v2.
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({
    super.key,
    this.billingOverride,
    this.currentTimezone = 'IST',
  });
  final PlayBillingService? billingOverride;
  final String currentTimezone;

  static const privacyUrl =
      'https://arun728.github.io/ekadashi-calendar/privacy-policy';
  static const termsUrl =
      'https://arun728.github.io/ekadashi-calendar/terms-of-service';

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  late PremiumService premium;
  late PlayBillingService billing;
  bool _initialized = false, _ownPremium = false, _ownBilling = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final provided = context.read<PremiumService?>();
    _ownPremium = provided == null;
    premium = provided ?? PremiumService(entitlements: PlayStoreEntitlements());
    final providedBilling =
        widget.billingOverride ?? context.read<PlayBillingService?>();
    _ownBilling = providedBilling == null;
    billing = providedBilling ?? PlayBillingService(premium);
    Future.microtask(billing.initialize);
  }

  @override
  void dispose() {
    if (_ownBilling) billing.dispose();
    if (_ownPremium) premium.dispose();
    super.dispose();
  }

  Future<void> _open(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  Future<void> _manage() => _open(
    Uri.https('play.google.com', '/store/account/subscriptions', {
      'package': 'com.applausestudios.ekadashi_calendar',
      'sku': PlayBillingService.subscription,
    }),
  );

  Widget _feature(BuildContext context, IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF00A19B)),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    return AnimatedBuilder(
      animation: Listenable.merge([premium, billing]),
      builder: (context, _) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: const Color(0xFF00A19B),
            onPrimary: Colors.white,
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style:
                (Theme.of(context).outlinedButtonTheme.style ??
                        const ButtonStyle())
                    .copyWith(
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style:
                (Theme.of(context).filledButtonTheme.style ??
                        const ButtonStyle())
                    .copyWith(
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
          ),
        ),
        child: Scaffold(
          appBar: AppBar(
            title: Text(lang.translate('premium_title')),
            leading: IconButton(
              key: const Key('premium_close'),
              tooltip: lang.translate('premium_continue_free'),
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.maybePop(context),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(lang.translate('premium_benefits')),
              const SizedBox(height: 8),
              _feature(
                context,
                Icons.sync,
                lang.translate('premium_feature_calendar'),
              ),
              _feature(
                context,
                Icons.self_improvement,
                lang.translate('premium_feature_vrat'),
              ),
              _feature(
                context,
                Icons.wb_twilight,
                lang.translate('premium_feature_panchang'),
              ),
              const SizedBox(height: 12),
              if (premium.isPremium)
                Text(
                  lang.translate('premium_active'),
                  key: const Key('premium_active'),
                  style: const TextStyle(
                    color: Color(0xFF00A19B),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (premium.busy) const LinearProgressIndicator(),
              if (billing.pending) Text(lang.translate('premium_pending')),
              for (final plan in billing.plans)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${lang.translate('premium_${plan.id}')} · ${plan.price}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (premium.subscribed &&
                            !premium.lifetime &&
                            plan.id == billing.currentPlanId)
                          Text(
                            lang.translate('premium_current_plan'),
                            key: Key('premium_current_${plan.id}'),
                            style: const TextStyle(color: Color(0xFF00A19B)),
                          ),
                        const SizedBox(height: 8),
                        Text(lang.translate('premium_${plan.id}_terms')),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: billing.canBuy(plan)
                              ? () => billing.buy(plan)
                              : null,
                          child: Text(
                            '${lang.translate('premium_${plan.id}')} · ${plan.price}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (billing.error != null && !premium.isPremium)
                Padding(
                  key: const Key('premium_status_message'),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(lang.translate(billing.error!)),
                ),
              TextButton(
                onPressed: premium.busy ? null : billing.restore,
                child: Text(lang.translate('premium_restore')),
              ),
              TextButton(
                onPressed: _manage,
                child: Text(lang.translate('premium_manage')),
              ),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(lang.translate('premium_continue_free')),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => _open(Uri.parse(PremiumScreen.termsUrl)),
                    child: Text(lang.translate('terms_of_service')),
                  ),
                  TextButton(
                    onPressed: () => _open(Uri.parse(PremiumScreen.privacyUrl)),
                    child: Text(lang.translate('privacy_policy')),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
