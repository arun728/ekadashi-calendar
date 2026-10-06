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

  String? _selected;

  /// Yearly first (best value), then the others, skipping plans that cannot
  /// be bought (for example the subscriber's current plan).
  PremiumPlan? _selectedPlan() {
    final plans = billing.plans;
    if (plans.isEmpty) return null;
    for (final plan in plans) {
      if (plan.id == _selected) return plan;
    }
    for (final id in ['yearly', 'monthly', 'lifetime']) {
      for (final plan in plans) {
        if (plan.id == id && billing.canBuy(plan)) return plan;
      }
    }
    return plans.first;
  }

  Widget _feature(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _teal, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    ),
  );

  static const _teal = Color(0xFF00A19B);

  Widget _planTile(LanguageService lang, PremiumPlan plan, bool selected) {
    final theme = Theme.of(context);
    final current =
        premium.subscribed &&
        !premium.lifetime &&
        plan.id == billing.currentPlanId;
    final period = switch (plan.id) {
      'monthly' => lang.translate('premium_per_month'),
      'yearly' => lang.translate('premium_per_year'),
      _ => lang.translate('premium_one_time'),
    };
    return Opacity(
      opacity: billing.canBuy(plan) || current ? 1 : 0.5,
      child: Material(
        color: selected
            ? _teal.withValues(alpha: 0.14)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? _teal : theme.dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('premium_plan_${plan.id}'),
          onTap: () => setState(() => _selected = plan.id),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
            child: Column(
              children: [
                SizedBox(
                  height: 20,
                  child: plan.id == 'yearly'
                      ? FittedBox(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _teal,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              lang.translate('premium_best_value'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 6),
                Text(
                  lang.translate('premium_${plan.id}'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    plan.price,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  period,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                if (current) ...[
                  const SizedBox(height: 4),
                  Text(
                    lang.translate('premium_current_plan'),
                    key: Key('premium_current_${plan.id}'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _teal, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _link(String label, VoidCallback? onPressed) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      textStyle: const TextStyle(fontSize: 13),
    ),
    child: Text(label),
  );

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    return AnimatedBuilder(
      animation: Listenable.merge([premium, billing]),
      builder: (context, _) {
        final selected = _selectedPlan();
        final showPlans = !premium.lifetime && billing.plans.isNotEmpty;
        return Scaffold(
          appBar: AppBar(
            title: Text(lang.translate('premium_title')),
            leading: IconButton(
              key: const Key('premium_close'),
              tooltip: lang.translate('premium_continue_free'),
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.maybePop(context),
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    children: [
                      _feature(
                        Icons.sync,
                        lang.translate('premium_feature_calendar'),
                      ),
                      _feature(
                        Icons.self_improvement,
                        lang.translate('premium_feature_vrat'),
                      ),
                      _feature(
                        Icons.wb_twilight,
                        lang.translate('premium_feature_panchang'),
                      ),
                      const SizedBox(height: 16),
                      if (premium.isPremium)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            lang.translate('premium_active'),
                            key: const Key('premium_active'),
                            style: const TextStyle(
                              color: _teal,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (premium.busy) const LinearProgressIndicator(),
                      if (billing.pending)
                        Text(lang.translate('premium_pending')),
                      if (showPlans)
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final plan in billing.plans) ...[
                                if (plan != billing.plans.first)
                                  const SizedBox(width: 8),
                                Expanded(
                                  child: _planTile(
                                    lang,
                                    plan,
                                    plan.id == selected?.id,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      if (showPlans && selected != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          lang.translate('premium_${selected.id}_terms'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (billing.error != null && !premium.isPremium)
                        Padding(
                          key: const Key('premium_status_message'),
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(lang.translate(billing.error!)),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showPlans && selected != null)
                        FilledButton(
                          key: const Key('premium_buy'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: billing.canBuy(selected)
                              ? () => billing.buy(selected)
                              : null,
                          child: Text(
                            '${lang.translate('premium_${selected.id}')} · ${selected.price}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          _link(
                            lang.translate('premium_restore'),
                            premium.busy ? null : billing.restore,
                          ),
                          _link(lang.translate('premium_manage'), _manage),
                          _link(
                            lang.translate('terms_of_service'),
                            () => _open(Uri.parse(PremiumScreen.termsUrl)),
                          ),
                          _link(
                            lang.translate('privacy_policy'),
                            () => _open(Uri.parse(PremiumScreen.privacyUrl)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
