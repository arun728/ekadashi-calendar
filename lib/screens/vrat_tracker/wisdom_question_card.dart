library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/wisdom_question.dart';
import '../../services/language_service.dart';
import '../../services/wisdom_progress_store.dart';
import '../../services/wisdom_question_service.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/ios_style.dart';

/// Question of the Day and Wisdom Challenge card supporting both Classic
/// and KBC quiz layouts, localized option labels, skipping, review mode,
/// preview indicators, and exhaustion states.
class WisdomQuestionCard extends StatefulWidget {
  const WisdomQuestionCard({
    super.key,
    this.questionService,
    this.progressStore,
    this.currentDate,
    this.isReviewMode = false,
  });

  final WisdomQuestionService? questionService;
  final WisdomProgressStore? progressStore;
  final DateTime? currentDate;
  final bool isReviewMode;

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
  bool _inReviewMode = false;
  int _reviewIndex = 0;
  List<String> _reviewQueue = [];

  @override
  void initState() {
    super.initState();
    _inReviewMode = widget.isReviewMode;
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
    if (_inReviewMode) {
      _startReviewMode();
      return;
    }

    final date = widget.currentDate ?? DateTime.now();
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
    if (_activeQuestionId != null && _store.isAnswered(_activeQuestionId!)) {
      final attempt = _store.getAttempt(_activeQuestionId!);
      _selectedOption = attempt?.selectedOption;
      _submitted = true;
    }
  }

  void _startReviewMode() {
    _inReviewMode = true;
    final incorrect = _store.incorrectQuestionIds;
    final skipped = _store.skippedQuestionIds;
    _reviewQueue = {...incorrect, ...skipped, ..._store.answeredIds}.toList();
    _reviewIndex = 0;
    if (_reviewQueue.isNotEmpty) {
      _activeQuestionId = _reviewQueue[_reviewIndex];
      final attempt = _store.getAttempt(_activeQuestionId!);
      _selectedOption = attempt?.selectedOption;
      _submitted = true;
    } else {
      _activeQuestionId = null;
    }
  }

  Future<void> _submitAnswer(WisdomQuestion question) async {
    if (_selectedOption == null || _submitted) return;

    final isCorrect = question.isCorrect(_selectedOption!);
    await _store.recordAttempt(
      questionId: question.questionId,
      selectedOption: _selectedOption!,
      isCorrect: isCorrect,
      isReview: _inReviewMode,
      isProductionEligible: question.publishable,
    );

    if (mounted) {
      setState(() {
        _submitted = true;
      });
    }
  }

  Future<void> _skipQuestion(WisdomQuestion question) async {
    await _store.recordAttempt(
      questionId: question.questionId,
      selectedOption: '',
      isCorrect: false,
      isSkipped: true,
      isReview: _inReviewMode,
      isProductionEligible: question.publishable,
    );

    _continueLearning();
  }

  void _continueLearning() {
    if (_inReviewMode) {
      setState(() {
        if (_reviewIndex < _reviewQueue.length - 1) {
          _reviewIndex++;
          _activeQuestionId = _reviewQueue[_reviewIndex];
          final attempt = _store.getAttempt(_activeQuestionId!);
          _selectedOption = attempt?.selectedOption;
          _submitted = true;
        } else {
          _inReviewMode = false;
          _finishedForToday = true;
        }
      });
      return;
    }

    final nextId = _service.nextQuestion(
      answeredIds: _store.answeredIds,
      excludeQuestionId: _activeQuestionId ?? '',
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
    final date = widget.currentDate ?? DateTime.now();
    _store.finishForToday(date);
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
      return _buildExhaustionCard(lang);
    }

    if (_finishedForToday) {
      return _buildCompletedTodayCard(lang);
    }

    final question = _service.getQuestion(_activeQuestionId!, langCode);
    if (question == null) return _buildExhaustionCard(lang);

    final attempt = _store.getAttempt(question.questionId);
    final isAnswered = _submitted || attempt != null;
    final selectedOpt = _selectedOption ?? attempt?.selectedOption;
    final isCorrect = attempt?.isCorrect ??
        (selectedOpt != null && question.isCorrect(selectedOpt));
    final isPreview = !question.publishable || _store.previewMode;

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
                  _inReviewMode
                      ? _service.getUIString('review', langCode, fallback: 'Review')
                      : _service.getUIString(
                          _isChallengeMode ? 'continue_learning' : 'todays_wisdom',
                          langCode,
                          fallback: _isChallengeMode
                              ? lang.translate('wisdom_challenge')
                              : lang.translate('question_of_the_day'),
                        ),
                  style: TextStyle(
                    fontSize: IosText.headline,
                    fontWeight: FontWeight.w700,
                    color: IosColors.primary(context),
                  ),
                ),
              ),
              if (isPreview) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    langCode == 'ta'
                        ? 'முன்னோட்டம்'
                        : langCode == 'hi'
                            ? 'पूर्वावलोकन'
                            : 'Preview',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
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

          // KBC Scenario / Context Box (if available)
          if (question.format == WisdomFormat.kbc &&
              question.context != null &&
              question.context!.trim().isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: teal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: teal.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(AppIcons.info, size: 16, color: teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      question.context!,
                      style: TextStyle(
                        fontSize: IosText.caption,
                        fontStyle: FontStyle.italic,
                        color: IosColors.secondary(context),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

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

          // Options A, B, C, D with Localized Option Keys
          for (final optKey in ['A', 'B', 'C', 'D'])
            if (question.options.containsKey(optKey)) ...[
              _buildOptionRow(
                context,
                optKey: optKey,
                displayKey: question.localizedOptionKey(optKey),
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

          // Submit & Skip Buttons (when not yet answered)
          if (!isAnswered) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
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
                      _service.getUIString('submit', langCode,
                          fallback: lang.translate('submit_answer')),
                      style: const TextStyle(
                        fontSize: IosText.subheadline,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    key: const Key('wisdom_skip_button'),
                    onPressed: () => _skipQuestion(question),
                    style: IosButtons.glass(context),
                    child: Text(
                      _service.getUIString('skip', langCode, fallback: 'Skip'),
                      style: IosButtons.label,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Post-Answer Results, Explanations & Insights
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
                        isCorrect ? AppIcons.checkmark : AppIcons.close,
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
                          color: isCorrect
                              ? Colors.green
                              : IosColors.secondary(context),
                        ),
                      ),
                    ],
                  ),

                  // Option feedback for incorrect answer (KBC)
                  if (!isCorrect &&
                      selectedOpt != null &&
                      question.optionFeedback != null &&
                      question.optionFeedback!.containsKey(selectedOpt)) ...[
                    const SizedBox(height: 6),
                    Text(
                      question.optionFeedback![selectedOpt]!,
                      style: const TextStyle(
                        fontSize: IosText.caption,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],

                  // Explanation of correct answer
                  const SizedBox(height: 8),
                  Text(
                    question.explanation,
                    style: TextStyle(
                      fontSize: IosText.caption,
                      color: IosColors.primary(context),
                    ),
                  ),

                  // Insight takeaway (KBC)
                  if (question.insight != null &&
                      question.insight!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(AppIcons.info, size: 16, color: teal),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              question.insight!,
                              style: TextStyle(
                                fontSize: IosText.caption2,
                                fontWeight: FontWeight.w600,
                                color: IosColors.primary(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                      _service.getUIString('continue_learning', langCode,
                          fallback: lang.translate('continue_learning')),
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
                      _service.getUIString('finish_for_today', langCode,
                          fallback: lang.translate('finish_for_today')),
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
    required String displayKey,
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
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? teal
                    : (isAnswered && isCorrectOption
                        ? Colors.green
                        : IosColors.gray(context).withValues(alpha: 0.15)),
              ),
              child: Text(
                displayKey,
                style: TextStyle(
                  fontSize: IosText.caption,
                  fontWeight: FontWeight.w700,
                  color: isSelected || (isAnswered && isCorrectOption)
                      ? Colors.white
                      : IosColors.primary(context),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                optText,
                style: TextStyle(
                  fontSize: IosText.body,
                  color: IosColors.primary(context),
                ),
              ),
            ),
            if (isAnswered && isCorrectOption) ...[
              const Icon(AppIcons.checkmark, size: 18, color: Colors.green),
            ] else if (isAnswered && isSelected && !isCorrectOption) ...[
              const Icon(AppIcons.close, size: 18, color: Colors.redAccent),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedTodayCard(LanguageService lang) {
    final langCode = lang.currentLocale.languageCode;
    return GlassPanel(
      radius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Icon(AppIcons.journeyBest, size: 40, color: teal),
          const SizedBox(height: 12),
          Text(
            _service.getUIString('completed_today', langCode,
                fallback: lang.translate('already_completed_today')),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: IosText.headline,
              fontWeight: FontWeight.w600,
              color: IosColors.primary(context),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _finishedForToday = false;
                      _continueLearning();
                    });
                  },
                  style: IosButtons.glass(context),
                  child: Text(
                    _service.getUIString('continue_learning', langCode,
                        fallback: lang.translate('wisdom_challenge')),
                    style: IosButtons.label,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _finishedForToday = false;
                      _startReviewMode();
                    });
                  },
                  style: IosButtons.glass(context),
                  child: Text(
                    _service.getUIString('review', langCode, fallback: 'Review'),
                    style: IosButtons.label,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExhaustionCard(LanguageService lang) {
    final langCode = lang.currentLocale.languageCode;
    final stats = _store.stats;

    return GlassPanel(
      radius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Icon(AppIcons.journeyMilestone, size: 40, color: teal),
          const SizedBox(height: 12),
          Text(
            _service.getUIString('completed_today', langCode,
                fallback: 'All questions completed!'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: IosText.headline,
              fontWeight: FontWeight.w700,
              color: IosColors.primary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${stats.totalCorrect}/${stats.totalAnswered} • ${stats.accuracyPercentage.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: IosText.subheadline,
              color: IosColors.secondary(context),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _finishedForToday = false;
                _startReviewMode();
              });
            },
            style: IosButtons.glass(context),
            child: Text(
              _service.getUIString('review', langCode, fallback: 'Review'),
              style: IosButtons.label,
            ),
          ),
        ],
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
              Expanded(
                child: Text(
                  lang.translate('wisdom_progress_title'),
                  style: TextStyle(
                    fontSize: IosText.headline,
                    fontWeight: FontWeight.w700,
                    color: IosColors.primary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatTile(
                  context,
                  title: lang.translate('total_answered'),
                  value: '${stats.totalAnswered}',
                  icon: AppIcons.cardObserved,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatTile(
                  context,
                  title: lang.translate('accuracy_rate'),
                  value: '${stats.accuracyPercentage.toStringAsFixed(0)}%',
                  icon: AppIcons.journeyStreak,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatTile(
                  context,
                  title: lang.translate('total_points'),
                  value: '${stats.totalPoints}',
                  icon: AppIcons.achievementStreak,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: IosColors.gray(context).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: teal),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: IosText.headline,
              fontWeight: FontWeight.w700,
              color: IosColors.primary(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: IosText.caption2,
              color: IosColors.secondary(context),
            ),
          ),
        ],
      ),
    );
  }
}
