import 'dart:async';
import '../services/display_clock.dart';
import 'package:flutter/material.dart';
import '../services/ekadashi_lifecycle.dart';
import '../services/ekadashi_service.dart';
import 'home_fasting_progress.dart';
import 'ios_style.dart';

/// A visible countdown ticks each second; progress each minute. No background
/// astronomy, network, storage or location work runs on a display tick.
class LifecycleBuilder extends StatefulWidget {
  const LifecycleBuilder({
    super.key,
    required this.event,
    required this.timezone,
    required this.builder,
  });
  final EkadashiDate event;
  final String timezone;
  final Widget Function(BuildContext, EkadashiLifecycle) builder;
  @override
  State<LifecycleBuilder> createState() => _LifecycleBuilderState();
}

class _LifecycleBuilderState extends State<LifecycleBuilder>
    with WidgetsBindingObserver {
  Timer? timer;
  bool active = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    schedule();
  }

  @override
  void didUpdateWidget(covariant LifecycleBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    schedule();
  }

  void schedule() {
    timer?.cancel();
    if (!active ||
        !TickerMode.of(context) ||
        (ModalRoute.of(context)?.isCurrent == false)) {
      return;
    }
    final now = DisplayClock.now();
    timer = Timer(
      EkadashiLifecycle.of(
        widget.event,
        now,
        widget.timezone,
      ).nextDelay(widget.event, now, widget.timezone),
      () {
        if (mounted) {
          setState(() {});
          schedule();
        }
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    schedule();
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    EkadashiLifecycle.of(widget.event, DisplayClock.now(), widget.timezone),
  );
}

class EkadashiLifecycleStatus extends StatelessWidget {
  const EkadashiLifecycleStatus({
    super.key,
    required this.event,
    required this.timezone,
    required this.language,
  });
  final EkadashiDate event;
  final String timezone, language;
  @override
  Widget build(BuildContext context) => LifecycleBuilder(
    event: event,
    timezone: timezone,
    builder: (context, state) => Row(
      children: [
        if (state.progress != null)
          HomeFastingProgress(fraction: state.progress!, language: language),
        if (state.progress != null) const SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: StatusPill(
              text: state.label(language),
              color: state.phase == EkadashiPhase.passed
                  ? IosColors.gray(context)
                  : IosColors.teal,
            ),
          ),
        ),
      ],
    ),
  );
}
