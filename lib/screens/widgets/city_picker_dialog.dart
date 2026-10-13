import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/indian_cities_data.dart';
import '../../services/native_location_service.dart';
import '../../services/language_service.dart';

/// Interactive modal dialog allowing users to:
/// 1. Use device location (GPS auto-detection)
/// 2. Filter cities by State/UT across all 36 Indian States and Union Territories
/// 3. Search cities by name or state
/// 4. View geographic coordinates (lat/lng)
class CityPickerDialog extends StatefulWidget {
  final LocationData? currentLocation;
  final Function(LocationData)? onLocationSelected;

  const CityPickerDialog({
    super.key,
    this.currentLocation,
    this.onLocationSelected,
  });

  static Future<LocationData?> show(
    BuildContext context, {
    LocationData? currentLocation,
    Function(LocationData)? onLocationSelected,
  }) {
    return showDialog<LocationData>(
      context: context,
      builder: (ctx) => CityPickerDialog(
        currentLocation: currentLocation,
        onLocationSelected: onLocationSelected,
      ),
    );
  }

  @override
  State<CityPickerDialog> createState() => _CityPickerDialogState();
}

class _CityPickerDialogState extends State<CityPickerDialog> {
  final NativeLocationService _locationService = NativeLocationService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedState = 'All';
  String _searchQuery = '';
  bool _isAutoDetect = true;
  bool _isDetecting = false;

  static const Color tealColor = Color(0xFF00A19B);

  @override
  void initState() {
    super.initState();
    _loadCurrentMode();
  }

  Future<void> _loadCurrentMode() async {
    final auto = await _locationService.isAutoDetectEnabled();
    if (mounted) {
      setState(() => _isAutoDetect = auto);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<IndianCity> get _filteredCities {
    return IndianCitiesData.searchCities(
      _searchQuery,
      state: _selectedState == 'All' ? null : _selectedState,
    );
  }

  Future<void> _handleAutoDetect() async {
    setState(() => _isDetecting = true);
    final lang = Provider.of<LanguageService>(context, listen: false);

    try {
      await _locationService.setAutoDetectEnabled(true);
      final hasPerm = await _locationService.hasLocationPermission();
      if (!hasPerm) {
        final granted = await _locationService.requestLocationPermission();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(lang.translate('location_permission_denied'))),
            );
            setState(() => _isDetecting = false);
          }
          return;
        }
      }

      final loc = await _locationService.getCurrentLocation();
      if (loc != null && mounted) {
        widget.onLocationSelected?.call(loc);
        Navigator.of(context).pop(loc);
      } else if (mounted) {
        setState(() => _isDetecting = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDetecting = false);
      }
    }
  }

  Future<void> _handleSelectCity(IndianCity city) async {
    final loc = await _locationService.selectManualCity(city);
    if (mounted) {
      widget.onLocationSelected?.call(loc);
      Navigator.of(context).pop(loc);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allStates = ['All', ...IndianCitiesData.statesAndUTs];

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 500,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.location_on, color: tealColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lang.translate('location_settings'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),

            // Auto-detect GPS button
            InkWell(
              onTap: _isDetecting ? null : _handleAutoDetect,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _isAutoDetect
                      ? tealColor.withOpacity(0.12)
                      : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isAutoDetect ? tealColor : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    _isDetecting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: tealColor),
                          )
                        : Icon(Icons.my_location, color: _isAutoDetect ? tealColor : Colors.grey),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.translate('current_location'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _isAutoDetect ? tealColor : null,
                            ),
                          ),
                          Text(
                            'GPS auto-detection (with permission)',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    if (_isAutoDetect)
                      const Icon(Icons.check_circle, color: tealColor, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '${lang.translate('city')} / ${lang.translate('state')}...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            const SizedBox(height: 8),

            // State Selector Dropdown
            Row(
              children: [
                Text(
                  '${lang.translate('state')}: ',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedState,
                        isExpanded: true,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        items: allStates.map((st) {
                          return DropdownMenuItem<String>(
                            value: st,
                            child: Text(
                              st == 'All' ? lang.translate('all_states') : st,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (newSt) {
                          if (newSt != null) {
                            setState(() => _selectedState = newSt);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Results count
            Text(
              '${_filteredCities.length} ${lang.translate('city')}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const Divider(),

            // City List
            Expanded(
              child: _filteredCities.isEmpty
                  ? Center(
                      child: Text(
                        'No cities found',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredCities.length,
                      itemBuilder: (ctx, index) {
                        final city = _filteredCities[index];
                        final isSelected = !_isAutoDetect &&
                            widget.currentLocation != null &&
                            widget.currentLocation!.city.toLowerCase() == city.name.toLowerCase();

                        return ListTile(
                          dense: true,
                          title: Text(
                            city.name,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? tealColor : null,
                            ),
                          ),
                          subtitle: Text(
                            '${city.state} • ${city.latitude.toStringAsFixed(2)}°N, ${city.longitude.toStringAsFixed(2)}°E • ${city.timezone}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check, color: tealColor, size: 20)
                              : null,
                          onTap: () => _handleSelectCity(city),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
