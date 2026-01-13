import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ekadashi_service.dart';
import '../services/native_location_service.dart';
import '../services/language_service.dart';

class CitySelectionScreen extends StatefulWidget {
  final String? currentCityId;
  final bool isAutoDetectEnabled;
  final Function(String cityId, String timezone, bool autoDetect) onCitySelected;

  const CitySelectionScreen({
    super.key,
    this.currentCityId,
    this.isAutoDetectEnabled = true,
    required this.onCitySelected,
  });

  @override
  State<CitySelectionScreen> createState() => _CitySelectionScreenState();
}

class _CitySelectionScreenState extends State<CitySelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCityId;
  bool _autoDetect = true;
  bool _isDetectingLocation = false;
  String? _detectedCity;
  String? _detectedTimezone;

  final _locationService = NativeLocationService();

  @override
  void initState() {
    super.initState();
    _selectedCityId = widget.currentCityId;
    _autoDetect = widget.isAutoDetectEnabled;

    if (_autoDetect) {
      _detectCurrentLocation();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _detectCurrentLocation() async {
    setState(() => _isDetectingLocation = true);

    try {
      final location = await _locationService.getCurrentLocation();
      if (location != null && mounted) {
        setState(() {
          _detectedCity = location.city;
          _detectedTimezone = location.timezone;
          _isDetectingLocation = false;
        });
      } else {
        setState(() => _isDetectingLocation = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDetectingLocation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageService>(context);
    const tealColor = Color(0xFF00A19B);
    final citiesByCountry = EkadashiService().getCitiesByCountry();

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.translate('select_city')),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Auto-detect toggle
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _autoDetect ? tealColor : Colors.grey.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.my_location,
                      color: _autoDetect ? tealColor : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.translate('auto_detect_location'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (_isDetectingLocation)
                            Text(
                              lang.translate('detecting_location'),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              ),
                            )
                          else if (_detectedCity != null && _autoDetect)
                            Text(
                              '$_detectedCity ($_detectedTimezone)',
                              style: TextStyle(
                                fontSize: 13,
                                color: tealColor,
                              ),
                            )
                          else
                            Text(
                              lang.translate('auto_detect_desc'),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _autoDetect,
                      activeColor: tealColor,
                      onChanged: (value) {
                        setState(() {
                          _autoDetect = value;
                          if (value) {
                            _selectedCityId = null;
                            _detectCurrentLocation();
                          }
                        });
                      },
                    ),
                  ],
                ),
                if (_isDetectingLocation)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),

          // Search bar
          if (!_autoDetect) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: lang.translate('search_city'),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value.toLowerCase());
                },
              ),
            ),
            const SizedBox(height: 8),
          ],

          // City list
          Expanded(
            child: _autoDetect
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_on,
                    size: 64,
                    color: tealColor.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    lang.translate('using_auto_location'),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lang.translate('disable_auto_manual'),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
                : ListView(
              children: citiesByCountry.entries.map((entry) {
                final country = entry.key;
                final cities = entry.value.where((city) {
                  if (_searchQuery.isEmpty) return true;
                  return city.name.toLowerCase().contains(_searchQuery) ||
                      city.country.toLowerCase().contains(_searchQuery);
                }).toList();

                if (cities.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Icon(
                            country == 'India'
                                ? Icons.flag
                                : Icons.flag_outlined,
                            size: 20,
                            color: tealColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            country,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: tealColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...cities.map((city) => _buildCityTile(city, tealColor)),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _canSave() ? _saveSelection : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: tealColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              Provider.of<LanguageService>(context).translate('save'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCityTile(CityInfo city, Color tealColor) {
    final isSelected = _selectedCityId == city.id;

    return ListTile(
      leading: Radio<String>(
        value: city.id,
        groupValue: _selectedCityId,
        activeColor: tealColor,
        onChanged: (value) {
          setState(() => _selectedCityId = value);
        },
      ),
      title: Text(city.name),
      subtitle: Text(
        city.timezone,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade500,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: tealColor)
          : null,
      onTap: () {
        setState(() => _selectedCityId = city.id);
      },
    );
  }

  bool _canSave() {
    if (_autoDetect) {
      return _detectedTimezone != null;
    }
    return _selectedCityId != null;
  }

  void _saveSelection() {
    if (_autoDetect && _detectedTimezone != null) {
      widget.onCitySelected('auto', _detectedTimezone!, true);
    } else if (_selectedCityId != null) {
      final timezone = EkadashiService().getTimezoneForCity(_selectedCityId!);
      widget.onCitySelected(_selectedCityId!, timezone, false);
    }
    Navigator.pop(context);
  }
}