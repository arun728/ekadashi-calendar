import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/wisdom_question.dart';
import '../../services/language_service.dart';
import '../../services/wisdom_progress_store.dart';
import '../../services/wisdom_question_service.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/ios_style.dart';

/// Question of the Day and Wisdom Challenge card displayed inside the
/// Achievement module (Journey tab).
class WisdomQuestionCard extends StatefulWidget {
  const WisdomQuestionCard({
    super.key,
    this.questionService,
    this.progressStore,
    this.currentDate,
  });

  final WisdomQuestionService? questionService;
  final WisdomProgressStore? progressStore;
  final DateTime? currentDate;

  @override
  State<WisdomQuestionCard> createState() => _WisdomQuestionCardState();
}

class _WisdomQuestionCardState extends State<WisdomQuestionCard> {
  static const teal = IosColors.teal;

  WisdomQuestionService get _service =>
      widget.questionService ?? WisdomQuestionService.instance;

  WisdomProgressStore get _store =>
      widget.progressStore ?? WisdomProgressStore.instance;

  String? _activeQuestionId;
  String? _selectedOption;
  bool _submitted = false;
  bool _isChallengeMode = false;
  bool _finishedForToday = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _store.load().then((_) {
          if (mounted) {
            _service.load().then((_) {
              if (mounted) {
                setState(() => _initializeDailyQuestion());
              }
            });
          }
        });
      }
    });
    _initializeDailyQuestion();
  }

  void _initializeDailyQuestion() {
    final date = widget.currentDate ?? DateTime.now();
    // Check if daily question is already assigned for today.
    var qId = _store.dailyQuestionIdFor(date);
    if (qId == null) {
      qId = _service.dailyQuestionId(
        date,
        answeredIds: _store.answeredIds,
      );
      if (qId != null) {
        _store.setDailyQuestion(qId, date);
      }
    }

    _activeQuestionId = qId;
    if (_activeQuestionId != null &&
        _store.isAnswered(_activeQuestionId!)) {
      final attempt = _store.getAttempt(_activeQuestionId!);
      _selectedOption = attempt?.selectedOption;
      _submitted = true;
    }
  }

  Future<void> _submitAnswer(WisdomQuestion question) async {
    if (_selectedOption == null || _submitted) return;

    final isCorrect = question.isCorrect(_selectedOption!);
    await _store.recordAttempt(
      questionId: question.questionId,
      selectedOption: _selectedOption!,
      isCorrect: isCorrect,
    );

    if (mounted) {
      setState(() {
        _submitted = true;
      });
    }
  }

  void _continueLearning() {
    if (_activeQuestionId == null) return;
    final nextId = _service.nextQuestion(
      answeredIds: _store.answeredIds,
      excludeQuestionId: _activeQuestionId!,
    );

    setState(() {
      if (nextId != null) {
        _activeQuestionId = nextId;
        _selectedOption = null;
        _submitted = false;
        _isChallengeMode = true;
        _finishedForToday = false;
      } else {
        _finishedForToday = true;
      }
    });
  }

  void _finishForToday() {
    setState(() {
      _finishedForToday = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    final langCode = lang.currentLocale.languageCode;
    final stats = _store.stats;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildQuestionCard(lang, langCode),
        const SizedBox(height: 16),
        _buildProgressSection(lang, langCode, stats),
      ],
    );
  }

  Widget _buildQuestionCard(LanguageService lang, String langCode) {
    if (_activeQuestionId == null) {
      return GlassPanel(
        radius: 16,
        padding: const EdgeInsets.all(16),
        child: Text(
          lang.translate('no_ekadashi'),
          textAlign: TextAlign.center,
          style: TextStyle(color: IosColors.secondary(context)),
        ),
      );
    }

    if (_finishedForToday) {
      return GlassPanel(
        radius: 16,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(AppIcons.journeyBest, size: 40, color: teal),
            const SizedBox(height: 12),
            Text(
              lang.translate('already_completed_today'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: IosText.headline,
                fontWeight: FontWeight.w600,
                color: IosColors.primary(context),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _finishedForToday = false;
                  _initializeDailyQuestion();
                });
              },
              style: IosButtons.glass(context),
              child: Text(
                lang.translate('wisdom_challenge'),
                style: IosButtons.label,
              ),
            ),
          ],
        ),
      );
    }

    final question = _service.getQuestion(
      _activeQuestionId!,
      langCode,
    );
    if (question == null) return const SizedBox.shrink();

    final attempt = _store.getAttempt(question.questionId);
    final isAnswered = _submitted || attempt != null;
    final selectedOpt = _selectedOption ?? attempt?.selectedOption;
    final isCorrect = attempt?.isCorrect ??
        (selectedOpt != null && question.isCorrect(selectedOpt));

    return GlassPanel(
      radius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title & Badges
          Row(
            children: [
              const Icon(AppIcons.categoryFestival, size: 20, color: teal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lang.translate(
                    _isChallengeMode ? 'wisdom_challenge' : 'question_of_the_day',
                  ),
                  style: TextStyle(
                    fontSize: IosText.headline,
                    fontWeight: FontWeight.w700,
                    color: IosColors.primary(context),
                  ),
                ),
              ),
              // Category Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: teal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  question.categoryLabel(langCode),
                  style: const TextStyle(
                    fontSize: IosText.caption2,
                    fontWeight: FontWeight.w600,
                    color: teal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Question Text
          Text(
            question.question,
            style: TextStyle(
              fontSize: IosText.body,
              fontWeight: FontWeight.w600,
              color: IosColors.primary(context),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),

          // Options A, B, C, D
          for (final optKey in ['A', 'B', 'C', 'D'])
            if (question.options.containsKey(optKey)) ...[
              _buildOptionRow(
                context,
                optKey: optKey,
                optText: question.options[optKey]!,
                isSelected: selectedOpt == optKey,
                isAnswered: isAnswered,
                isCorrectOption: question.correctOption == optKey,
                onTap: isAnswered
                    ? null
                    : () => setState(() => _selectedOption = optKey),
              ),
              const SizedBox(height: 8),
            ],

          // Submit Button (when not yet answered)
          if (!isAnswered) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('wisdom_submit_button'),
                onPressed: _selectedOption != null
                    ? () => _submitAnswer(question)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: teal,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: teal.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  lang.translate('submit_answer'),
                  style: const TextStyle(
                    fontSize: IosText.subheadline,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],

          // Post-Answer Results & Actions
          if (isAnswered) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCorrect
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCorrect ? Colors.green : Colors.redAccent,
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isCorrect ? Icons.check_circle : Icons.cancel,
                        color: isCorrect ? Colors.green : Colors.redAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        lang.translate(
                          isCorrect ? 'answer_correct' : 'answer_incorrect',
                        ),
                        style: TextStyle(
                          fontSize: IosText.subheadline,
                          fontWeight: FontWeight.w700,
                          color: isCorrect ? Colors.green : Colors.redAccent,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        lang.translateWithArgs('points_earned', [
                          isCorrect ? '1' : '0',
                        ]),
                        style: TextStyle(
                          fontSize: IosText.caption,
                          fontWeight: FontWeight.w700,
                          color: isCorrect ? Colors.green : IosColors.secondary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    question.explanation,
                    style: TextStyle(
                      fontSize: IosText.caption,
                      color: IosColors.primary(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('wisdom_continue_button'),
                    onPressed: _continueLearning,
                    style: IosButtons.glass(context),
                    child: Text(
                      lang.translate('continue_learning'),
                      style: IosButtons.label,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('wisdom_finish_button'),
                    onPressed: _finishForToday,
                    style: IosButtons.glass(context),
                    child: Text(
                      lang.translate('finish_for_today'),
                      style: IosButtons.label,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionRow(
    BuildContext context, {
    required String optKey,
    required String optText,
    required bool isSelected,
    required bool isAnswered,
    required bool isCorrectOption,
    required VoidCallback? onTap,
  }) {
    Color? borderColor;
    Color? bgColor;

    if (isAnswered) {
      if (isCorrectOption) {
        borderColor = Colors.green;
        bgColor = Colors.green.withValues(alpha: 0.1);
      } else if (isSelected) {
        borderColor = Colors.redAccent;
        bgColor = Colors.redAccent.withValues(alpha: 0.1);
      }
    } else if (isSelected) {
      borderColor = teal;
      bgColor = teal.withValues(alpha: 0.12);
    }

    return InkWell(
      key: Key('wisdom_option_$optKey'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor ?? IosColors.gray(context).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: borderColor ?? IosColors.gray(context).withValues(alpha: 0.2),
            width: isSelected || (isAnswered && isCorrectOption) ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? teal
                    : IosColors.gray(context).withValues(alpha: 0.15),
              ),
              child: Text(
                optKey,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : IosColors.primary(context),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                optText,
                style: TextStyle(
                  fontSize: IosText.subheadline,
                  color: IosColors.primary(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(
    LanguageService lang,
    String langCode,
    WisdomStats stats,
  ) {
    return GlassPanel(
      key: const Key('wisdom_progress_section'),
      radius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.journeyMilestone, size: 20, color: teal),
              const SizedBox(width: 8),
              Text(
                lang.translate('wisdom_challenge'),
                style: TextStyle(
                  fontSize: IosText.headline,
                  fontWeight: FontWeight.w700,
                  color: IosColors.primary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _metricTile(
                context,
                title: lang.translate('total_points'),
                value: '${stats.totalPoints}',
                color: teal,
              ),
              const SizedBox(width: 8),
              _metricTile(
                context,
                title: lang.translate('questions_answered'),
                value: '${stats.totalAnswered}',
                color: Colors.orange,
              ),
              const SizedBox(width: 8),
              _metricTile(
                context,
                title: lang.translate('correct_answers'),
                value: '${stats.totalCorrect}',
                color: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            lang.translate('category_progress'),
            style: TextStyle(
              fontSize: IosText.subheadline,
              fontWeight: FontWeight.w600,
              color: IosColors.secondary(context),
            ),
          ),
          const SizedBox(height: 8),
          _categoryProgressRow(lang, 'ekadashi', 'category_ekadashi'),
          const SizedBox(height: 6),
          _categoryProgressRow(lang, 'bhagavad_gita', 'category_bhagavad_gita'),
          const SizedBox(height: 6),
          _categoryProgressRow(lang, 'mahabharata', 'category_mahabharata'),
          const SizedBox(height: 6),
          _categoryProgressRow(lang, 'ramayana', 'category_ramayana'),
        ],
      ),
    );
  }

  Widget _metricTile(
    BuildContext context, {
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: IosText.caption2,
                color: IosColors.secondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryProgressRow(
    LanguageService lang,
    String categoryKey,
    String labelKey,
  ) {
    // Count questions for category.
    final total = _service.allQuestionIds.where((id) {
      final q = _service.getQuestion(id, 'en');
      return q?.category == categoryKey;
    }).length;

    var answered = 0;
    var correct = 0;
    for (final attempt in _store.attempts.values) {
      final q = _service.getQuestion(attempt.questionId, 'en');
      if (q?.category == categoryKey) {
        answered++;
        if (attempt.isCorrect) correct++;
      }
    }

    final pct = total > 0 ? (answered / total).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              lang.translate(labelKey),
              style: TextStyle(
                fontSize: IosText.caption,
                fontWeight: FontWeight.w600,
                color: IosColors.primary(context),
              ),
            ),
            Text(
              '$answered/$total ($correct ✓)',
              style: TextStyle(
                fontSize: IosText.caption2,
                color: IosColors.secondary(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: IosColors.gray(context).withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(teal),
          ),
        ),
      ],
    );
  }
}
