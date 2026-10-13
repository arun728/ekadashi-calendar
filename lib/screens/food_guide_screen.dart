import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/food_guide_models.dart';
import '../services/food_guide_service.dart';
import '../services/language_service.dart';
import '../services/tradition_service.dart';

class FoodGuideScreen extends StatefulWidget {
  final AppTradition? initialTradition;

  const FoodGuideScreen({
    super.key,
    this.initialTradition,
  });

  @override
  State<FoodGuideScreen> createState() => _FoodGuideScreenState();
}

class _FoodGuideScreenState extends State<FoodGuideScreen> {
  static const Color tealColor = Color(0xFF00A19B);

  final TextEditingController _searchController = TextEditingController();
  final FoodGuideService _foodService = FoodGuideService();

  bool _isLoading = true;
  AppTradition? _selectedTradition;
  String _selectedCategory = 'all';
  FoodFastStatus? _selectedStatus;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _foodService.initializeData();
    if (mounted) {
      final ts = Provider.of<TraditionService>(context, listen: false);
      setState(() {
        _selectedTradition = widget.initialTradition ?? ts.currentTradition;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    final traditionService = Provider.of<TraditionService>(context);
    final langCode = lang.currentLocale.languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeTradition = _selectedTradition ?? traditionService.currentTradition;

    final filteredItems = _foodService.filterItems(
      tradition: activeTradition,
      categoryId: _selectedCategory,
      status: _selectedStatus,
      searchQuery: _searchQuery,
      languageCode: langCode,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.translate('food_guide_title')),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: tealColor))
          : Column(
              children: [
                // Top control bar: Search + Tradition filter
                Container(
                  color: Theme.of(context).cardColor,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    children: [
                      // Search bar
                      TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: lang.translate('search_food_hint'),
                          prefixIcon: const Icon(Icons.search, color: tealColor),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: tealColor.withOpacity(0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: tealColor.withOpacity(0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: tealColor, width: 1.5),
                          ),
                          filled: true,
                          fillColor: isDark ? Colors.white10 : Colors.grey.shade50,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Tradition Toggle Chips
                      Row(
                        children: [
                          Icon(Icons.filter_alt_outlined, size: 16, color: tealColor.withOpacity(0.8)),
                          const SizedBox(width: 6),
                          Text(
                            '${lang.translate('tradition')}:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildTraditionChip(
                                    label: lang.translate('tradition_general'),
                                    tradition: AppTradition.general,
                                    isSelected: activeTradition == AppTradition.general,
                                  ),
                                  const SizedBox(width: 6),
                                  _buildTraditionChip(
                                    label: lang.translate('tradition_smarta'),
                                    tradition: AppTradition.smarta,
                                    isSelected: activeTradition == AppTradition.smarta,
                                  ),
                                  const SizedBox(width: 6),
                                  _buildTraditionChip(
                                    label: lang.translate('tradition_vaishnava'),
                                    tradition: AppTradition.vaishnava,
                                    isSelected: activeTradition == AppTradition.vaishnava,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Category & Status Filters
                Container(
                  color: Theme.of(context).cardColor,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Category pills
                        _buildFilterPill(
                          label: lang.translate('all_categories'),
                          isSelected: _selectedCategory == 'all',
                          onTap: () => setState(() => _selectedCategory = 'all'),
                        ),
                        ..._foodService.categories.map((cat) => Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: _buildFilterPill(
                                label: cat.localizedName(langCode),
                                isSelected: _selectedCategory == cat.id,
                                onTap: () => setState(() => _selectedCategory = cat.id),
                              ),
                            )),
                        const SizedBox(width: 12),
                        Container(height: 16, width: 1, color: Colors.grey.withOpacity(0.3)),
                        const SizedBox(width: 12),
                        // Status pills
                        _buildStatusPill(
                          label: lang.translate('all_statuses'),
                          isSelected: _selectedStatus == null,
                          onTap: () => setState(() => _selectedStatus = null),
                        ),
                        const SizedBox(width: 6),
                        _buildStatusPill(
                          label: lang.translate('food_status_allowed'),
                          status: FoodFastStatus.allowed,
                          isSelected: _selectedStatus == FoodFastStatus.allowed,
                          onTap: () => setState(() => _selectedStatus =
                              _selectedStatus == FoodFastStatus.allowed ? null : FoodFastStatus.allowed),
                        ),
                        const SizedBox(width: 6),
                        _buildStatusPill(
                          label: lang.translate('food_status_restricted'),
                          status: FoodFastStatus.restricted,
                          isSelected: _selectedStatus == FoodFastStatus.restricted,
                          onTap: () => setState(() => _selectedStatus =
                              _selectedStatus == FoodFastStatus.restricted ? null : FoodFastStatus.restricted),
                        ),
                        const SizedBox(width: 6),
                        _buildStatusPill(
                          label: lang.translate('food_status_optional'),
                          status: FoodFastStatus.optional,
                          isSelected: _selectedStatus == FoodFastStatus.optional,
                          onTap: () => setState(() => _selectedStatus =
                              _selectedStatus == FoodFastStatus.optional ? null : FoodFastStatus.optional),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),

                // Food Items List
                Expanded(
                  child: filteredItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                lang.translate('no_foods_found'),
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredItems.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            return _buildFoodCard(
                              context,
                              item: item,
                              langCode: langCode,
                              userTradition: activeTradition,
                              isDark: isDark,
                              lang: lang,
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildTraditionChip({
    required String label,
    required AppTradition tradition,
    required bool isSelected,
  }) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : tealColor,
        ),
      ),
      selected: isSelected,
      selectedColor: tealColor,
      backgroundColor: tealColor.withOpacity(0.08),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => setState(() => _selectedTradition = tradition),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? tealColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? tealColor : Colors.grey.withOpacity(0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? tealColor : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill({
    required String label,
    FoodFastStatus? status,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    Color baseColor = tealColor;
    if (status == FoodFastStatus.allowed) baseColor = Colors.green.shade700;
    if (status == FoodFastStatus.restricted) baseColor = Colors.red.shade700;
    if (status == FoodFastStatus.optional) baseColor = Colors.orange.shade800;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? baseColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? baseColor : Colors.grey.withOpacity(0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? baseColor : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildFoodCard(
    BuildContext context, {
    required VratFoodItem item,
    required String langCode,
    required AppTradition userTradition,
    required bool isDark,
    required LanguageService lang,
  }) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (item.status) {
      case FoodFastStatus.allowed:
        statusColor = const Color(0xFF2E7D32); // Deep Green
        statusIcon = Icons.check_circle_outline;
        statusText = lang.translate('food_status_allowed');
        break;
      case FoodFastStatus.restricted:
        statusColor = const Color(0xFFC62828); // Deep Red
        statusIcon = Icons.block;
        statusText = lang.translate('food_status_restricted');
        break;
      case FoodFastStatus.optional:
        statusColor = const Color(0xFFEF6C00); // Amber / Orange
        statusIcon = Icons.swap_horiz;
        statusText = lang.translate('food_status_optional');
        break;
    }

    final hasTraditionDiff = item.hasAlternativePerspective(userTradition);
    final alternative = item.localizedAlternative(langCode);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name + Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.localizedName(langCode),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 13, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Explanation
          Text(
            item.localizedExplanation(langCode),
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),

          // Suggested alternative if available
          if (alternative != null && alternative.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, size: 14, color: tealColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${lang.translate('suggested_alternative')} $alternative',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Tradition Difference Notice if applicable
          if (hasTraditionDiff) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 12, color: Colors.orange.shade800),
                  const SizedBox(width: 6),
                  Text(
                    lang.translate('tradition_difference'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
