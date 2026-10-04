import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../services/language_service.dart';
import '../services/premium_service.dart';
import '../services/premium_http_backend.dart';
import '../services/play_billing_service.dart';
import '../services/reward_wallet_service.dart';
import '../services/vrat_tracker_service.dart';

Future<void> openPremium(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const PremiumScreen()));

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key, this.billingOverride});
  final PlayBillingService? billingOverride;
  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  late PremiumService premium;
  late PlayBillingService billing;
  late RewardWalletService wallet;
  bool _initialized = false,
      _ownPremium = false,
      _ownBilling = false,
      _ownWallet = false;
  String? _redeemKey;
  String? _lastAccount;
  Future<void> _accountChanged() async {
    if (_lastAccount == premium.accountId) return;
    _lastAccount = premium.accountId;
    final account = premium.accountId;
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    _redeemKey = account == null
        ? null
        : p.getString('rewards_redemption_$account');
    if (account != null) await wallet.refresh();
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final provided = context.read<PremiumService?>();
    _ownPremium = provided == null;
    premium = provided ?? PremiumService(backend: PremiumHttpBackend());
    final providedBilling =
        widget.billingOverride ?? context.read<PlayBillingService?>();
    _ownBilling = providedBilling == null;
    billing = providedBilling ?? PlayBillingService(premium);
    final providedWallet = context.read<RewardWalletService?>();
    _ownWallet = providedWallet == null;
    wallet = providedWallet ?? RewardWalletService(premium.backend);
    premium.addListener(_accountChanged);
    Future.microtask(() async {
      await billing.initialize();
      await _accountChanged();
    });
  }

  @override
  void dispose() {
    premium.removeListener(_accountChanged);
    if (_ownBilling) billing.dispose();
    if (_ownWallet) wallet.dispose();
    if (_ownPremium) premium.dispose();
    super.dispose();
  }

  Future<void> _manage() async {
    await launchUrl(
      Uri.https('play.google.com', '/store/account/subscriptions', {
        'package': 'com.applausestudios.ekadashi_calendar',
        'sku': PlayBillingService.subscription,
      }),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<bool> _confirm(String key) async {
    final lang = context.read<LanguageService>();
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            content: Text(lang.translate(key)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(lang.translate('cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  lang.translate(
                    key == 'premium_delete_warning'
                        ? 'premium_delete_account'
                        : 'premium_reward_activate',
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _activate() async {
    final tracker = context.read<VratTrackerService?>();
    if (!await _confirm('premium_reward_consent')) return;
    if (!premium.connected) await premium.connect();
    final account = premium.accountId;
    if (account == null || !mounted) return;
    await wallet.activate(account);
    await wallet.sync(account, {
      for (final r in tracker?.getAllRecords() ?? [])
        if (r.occurrenceUid != null) r.occurrenceUid!: r.status.key,
    }, 'IST');
    await wallet.refresh();
  }

  Future<void> _delete() async {
    if (!await _confirm('premium_delete_warning')) return;
    final account = premium.accountId;
    try {
      await premium.deleteAccount();
      if (account != null) await wallet.forget(account);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.read<LanguageService>().translate('premium_unavailable'),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageService>();
    return AnimatedBuilder(
      animation: Listenable.merge([premium, billing, wallet]),
      builder: (context, _) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: const Color(0xFF00A19B),
            onPrimary: Colors.white,
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
              const SizedBox(height: 16),
              if (premium.isPremium)
                Text(
                  lang.translate('premium_active'),
                  style: const TextStyle(
                    color: Color(0xFF00A19B),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (!premium.connected)
                FilledButton(
                  onPressed: premium.busy ? null : premium.connect,
                  child: Text(lang.translate('premium_sign_in')),
                ),
              if (premium.busy || wallet.busy) const LinearProgressIndicator(),
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
                        const SizedBox(height: 8),
                        Text(lang.translate('premium_${plan.id}_terms')),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed:
                              !premium.connected ||
                                  premium.busy ||
                                  billing.pending ||
                                  premium.autoRenew ||
                                  premium.lifetime
                              ? null
                              : () => billing.buy(plan),
                          child: Text(
                            '${lang.translate('premium_${plan.id}')} · ${plan.price}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (billing.error != null || premium.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(lang.translate(premium.error ?? billing.error!)),
                ),
              TextButton(
                onPressed: billing.restore,
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
              const Divider(height: 32),
              Text(
                lang.translate('premium_wallet'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(lang.translate('premium_reward_rules')),
              const SizedBox(height: 8),
              Text(lang.translate('premium_reward_example')),
              const SizedBox(height: 12),
              Text('${lang.translate('premium_coins')}: ${wallet.coins}'),
              if (wallet.error != null) Text(lang.translate(wallet.error!)),
              OutlinedButton(
                onPressed: premium.busy || wallet.busy ? null : _activate,
                child: Text(lang.translate('premium_reward_activate')),
              ),
              FilledButton(
                onPressed:
                    premium.connected &&
                        (wallet.coins >= 300 || _redeemKey != null) &&
                        !premium.lifetime &&
                        !premium.busy &&
                        !wallet.busy
                    ? () async {
                        final p = await SharedPreferences.getInstance();
                        _redeemKey ??=
                            p.getString(
                              'rewards_redemption_${premium.accountId}',
                            ) ??
                            const Uuid().v4();
                        if (!await p.setString(
                          'rewards_redemption_${premium.accountId}',
                          _redeemKey!,
                        )) {
                          return;
                        }
                        await premium.redeem(_redeemKey!);
                        await wallet.refresh();
                        if (premium.error == null &&
                            premium.redemptionState == 'completed') {
                          await p.remove(
                            'rewards_redemption_${premium.accountId}',
                          );
                          _redeemKey = null;
                        }
                      }
                    : null,
                child: Text(
                  lang.translate(
                    _redeemKey != null ? 'retry' : 'premium_redeem',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                lang.translate('premium_terms'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(lang.translate('premium_reward_consent')),
              for (final url in [
                PremiumHttpBackend.privacyUrl,
                PremiumHttpBackend.termsUrl,
                PremiumHttpBackend.deletionUrl,
              ])
                if (PremiumHttpBackend.validHttps(url))
                  TextButton(
                    onPressed: () => launchUrl(
                      Uri.parse(url),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Text(lang.translate('premium_terms')),
                  ),
              if (premium.connected)
                TextButton(
                  onPressed: _delete,
                  child: Text(lang.translate('premium_delete_account')),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
