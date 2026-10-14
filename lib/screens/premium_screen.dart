import 'package:flutter/material.dart';
import '../widgets/app_background.dart';
import '../widgets/ios_style.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/language_service.dart';
import '../services/premium_service.dart';
import '../services/play_billing_service.dart';
import '../widgets/app_icons.dart';

/// Opens the paywall; [reasonKey] is a translation key saying why (for
/// example, the free Google Calendar sync was used).
Future<void> openPremium(
  BuildContext context, {
  String currentTimezone = 'IST',
  String? reasonKey,
}) => showAppSheet<void>(
  // A sheet over everything, as the iOS paywall.
  context,
  builder: (_) =>
      PremiumScreen(currentTimezone: currentTimezone, reasonKey: reasonKey),
);

/// Paywall. Premium is bought and restored through Google Play only; no
/// Google sign-in, server account or rewards are involved in v2.
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({
    super.key,
    this.billingOverride,
    this.currentTimezone = 'IST',
    this.reasonKey,
  });
  final PlayBillingService? billingOverride;
  final String currentTimezone;

  /// Why the paywall opened, shown above the plans (translation key).
  final String? reasonKey;

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

  /// A feature line: the iOS symbol in teal and the text at body size.
  Widget _feature(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 26, child: Icon(icon, color: IosColors.teal, size: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: IosText.body,
              color: IosColors.primary(context),
            ),
          ),
        ),
      ],
    ),
  );

  /// A plan tile (iOS tile): a glass card, teal-tinted with a teal border
  /// when selected.
  Widget _planTile(LanguageService lang, PremiumPlan plan, bool selected) {
    final current =
        premium.subscribed &&
        !premium.lifetime &&
        plan.id == billing.currentPlanId;
    final period = switch (plan.id) {
      'monthly' => lang.translate('premium_per_month'),
      'yearly' => lang.translate('premium_per_year'),
      _ => lang.translate('premium_one_time'),
    };
    final secondary = IosColors.secondary(context);
    return Semantics(
      key: Key('premium_plan_${plan.id}'),
      button: true,
      selected: selected,
      child: Opacity(
        opacity: billing.canBuy(plan) || current ? 1 : 0.5,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? IosColors.teal
                  : IosColors.gray(context).withValues(alpha: .3),
              width: selected ? 2 : 1,
            ),
          ),
          child: GlassPanel(
            radius: 16,
            tint: selected ? IosColors.teal : null,
            onTap: () => setState(() => _selected = plan.id),
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
                            decoration: const ShapeDecoration(
                              color: IosColors.teal,
                              shape: StadiumBorder(),
                            ),
                            child: Text(
                              lang.translate('premium_best_value'),
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: IosText.caption2,
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
                  style: TextStyle(
                    fontSize: IosText.subheadline,
                    fontWeight: FontWeight.w600,
                    color: IosColors.primary(context),
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    plan.price,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: IosText.title3,
                      fontWeight: FontWeight.w700,
                      color: IosColors.primary(context),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  period,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: IosText.caption, color: secondary),
                ),
                if (current) ...[
                  const SizedBox(height: 6),
                  Text(
                    lang.translate('premium_current_plan'),
                    key: Key('premium_current_${plan.id}'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: IosColors.teal,
                      fontSize: IosText.caption,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _restore(LanguageService lang) async {
    final result = await billing.restore();
    if (!mounted) return;
    final key = switch (result) {
      RestoreResult.restored => 'premium_restored',
      RestoreResult.none => 'premium_restore_none',
      RestoreResult.unavailable => 'premium_unavailable',
    };
    showToast(context, lang.translate(key));
  }

  /// Google Play cannot cancel a subscription for the app, so a subscriber
  /// is told before buying lifetime that they must cancel it themselves.
  Future<void> _buy(LanguageService lang, PremiumPlan plan) async {
    if (plan.id == 'lifetime' && premium.subscribed) {
      final go = await showDialog<bool>(
        context: context,
        useRootNavigator: true,
        builder: (context) {
          final style = TextButton.styleFrom(foregroundColor: IosColors.teal);
          return AlertDialog(
            title: Text(lang.translate('premium_lifetime_confirm_title')),
            content: Text(lang.translate('premium_lifetime_confirm_body')),
            actions: [
              TextButton(
                style: style,
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  lang.translate('cancel'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                style: style,
                onPressed: () => Navigator.pop(context, true),
                child: Text(lang.translate('premium_buy_lifetime_anyway')),
              ),
            ],
          );
        },
      );
      if (go != true) return;
    }
    await billing.buy(plan);
  }

  /// A member status card: a glass panel tinted with [color].
  Widget _statusCard({
    required String title,
    required String body,
    Widget? action,
    Color color = IosColors.teal,
    Key? key,
  }) => SizedBox(
    key: key,
    width: double.infinity,
    child: GlassPanel(
      radius: 16,
      tint: color,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: IosText.headline,
              fontWeight: FontWeight.w600,
              color: IosColors.primary(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontSize: IosText.subheadline,
              color: IosColors.primary(context),
            ),
          ),
          if (action != null) ...[const SizedBox(height: 12), action],
        ],
      ),
    ),
  );

  /// A footer link: 13 pt teal, as the iOS footnote buttons.
  Widget _link(String label, VoidCallback? onPressed) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: IosColors.teal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      minimumSize: const Size(0, 32),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: IosText.footnote,
        color: onPressed == null ? IosColors.tertiary(context) : IosColors.teal,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    return AnimatedBuilder(
      animation: Listenable.merge([premium, billing]),
      builder: (context, _) {
        final selected = _selectedPlan();
        final showPlans = !premium.lifetime && billing.plans.isNotEmpty;
        final orange = IosColors.orange(context);
        return AppBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              centerTitle: true,
              title: Text(
                lang.translate('premium_title'),
                style: iosNavTitle(context),
              ),
              leading: IconButton(
                key: const Key('premium_close'),
                tooltip: lang.translate('premium_continue_free'),
                icon: const Icon(AppIcons.close),
                color: IosColors.teal,
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      children: [
                        if (premium.lifetime) ...[
                          _statusCard(
                            key: const Key('premium_lifetime_thanks'),
                            title: lang.translate(
                              'premium_lifetime_thanks_title',
                            ),
                            body: lang.translate(
                              'premium_lifetime_thanks_body',
                            ),
                          ),
                          if (premium.subscribed) ...[
                            const SizedBox(height: 12),
                            _statusCard(
                              color: orange,
                              title: lang.translate('premium_active'),
                              body: lang.translate(
                                'premium_cancel_subscription_note',
                              ),
                              action: OutlinedButton(
                                key: const Key('premium_cancel_subscription'),
                                style: IosButtons.glass(context),
                                onPressed: _manage,
                                child: Text(
                                  lang.translate(
                                    'premium_cancel_subscription_action',
                                  ),
                                  style: IosButtons.label,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                        ] else if (premium.subscribed) ...[
                          Padding(
                            key: const Key('premium_active'),
                            padding: const EdgeInsets.only(bottom: 12),
                            child: premium.subscriptionCancelled
                                ? _statusCard(
                                    color: orange,
                                    title: lang.translate(
                                      'premium_cancelled_title',
                                    ),
                                    body: lang.translate(
                                      'premium_cancelled_body',
                                    ),
                                  )
                                : _statusCard(
                                    title: lang.translate(
                                      'premium_subscriber_title',
                                    ),
                                    body: lang.translate(
                                      'premium_subscriber_body',
                                    ),
                                  ),
                          ),
                        ] else ...[
                          if (widget.reasonKey != null)
                            Padding(
                              key: const Key('premium_reason'),
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(
                                    width: 26,
                                    child: Icon(
                                      AppIcons.info,
                                      color: IosColors.teal,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      lang.translate(widget.reasonKey!),
                                      style: TextStyle(
                                        fontSize: IosText.body,
                                        fontWeight: FontWeight.w600,
                                        color: IosColors.primary(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          _feature(
                            AppIcons.premiumCalendar,
                            lang.translate('premium_feature_calendar'),
                          ),
                          _feature(
                            AppIcons.premiumVrat,
                            lang.translate('premium_feature_vrat'),
                          ),
                          _feature(
                            AppIcons.premiumPanchang,
                            lang.translate('premium_feature_panchang_v2'),
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (premium.busy)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Center(
                              child: SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: IosColors.teal,
                                ),
                              ),
                            ),
                          ),
                        if (billing.pending)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              lang.translate('premium_pending'),
                              style: TextStyle(
                                fontSize: IosText.subheadline,
                                color: IosColors.primary(context),
                              ),
                            ),
                          ),
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
                            style: TextStyle(
                              fontSize: IosText.caption,
                              color: IosColors.secondary(context),
                            ),
                          ),
                        ],
                        if (billing.error != null && !premium.isPremium)
                          Padding(
                            key: const Key('premium_status_message'),
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              lang.translate(billing.error!),
                              style: TextStyle(
                                fontSize: IosText.subheadline,
                                color: IosColors.primary(context),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showPlans && selected != null)
                          FilledButton(
                            key: const Key('premium_buy'),
                            style: IosButtons.prominent(vertical: 14),
                            onPressed: billing.canBuy(selected)
                                ? () => _buy(lang, selected)
                                : null,
                            child: Text(
                              premium.subscriptionCancelled &&
                                      selected.id == billing.currentPlanId
                                  ? '${lang.translate('premium_reactivate')} · ${selected.price}'
                                  : '${lang.translate('premium_${selected.id}')} · ${selected.price}',
                              textAlign: TextAlign.center,
                              style: IosButtons.label,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Wrap(
                          key: const Key('premium_links'),
                          alignment: WrapAlignment.start,
                          spacing: 4,
                          children: [
                            _link(
                              lang.translate('premium_restore'),
                              premium.busy ? null : () => _restore(lang),
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
          ),
        );
      },
    );
  }
}
