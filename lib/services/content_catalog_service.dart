import 'search_matching.dart';
import '../l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/search_content_type.dart';
import '../models/search_index_entry.dart';
import 'ekadashi_service.dart';

/// Centralized service providing the catalog of content across all 8 searchable types.
/// Supports local and online-only content with persistent download capabilities (EC2-FR-079, EC2-FR-080, EC2-FR-081).
class ContentCatalogService {
  static const String _downloadedIdsKey = 'ec2_downloaded_content_ids';

  static final ContentCatalogService _instance =
      ContentCatalogService._internal();
  factory ContentCatalogService() => _instance;
  ContentCatalogService._internal();

  final Set<String> _downloadedIds = {};
  bool _initialized = false;

  /// Load persistent download statuses
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_downloadedIdsKey) ?? [];
      _downloadedIds.addAll(saved);
      _initialized = true;
    } catch (_) {
      _initialized = true;
    }
  }

  /// Check whether an item is downloaded
  bool isItemDownloaded(String id) {
    return _downloadedIds.contains(id);
  }

  /// Download an online-only item, persisting its downloaded status
  Future<bool> downloadItem(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final updated = {..._downloadedIds, id};
      final saved = await prefs.setStringList(
        _downloadedIdsKey,
        updated.toList(),
      );
      if (!saved) {
        await prefs.reload();
        return false;
      }
      _downloadedIds.add(id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Build index entries for all 8 categories
  Future<List<SearchIndexEntry>> buildAllCatalogEntries({
    required List<EkadashiDate> ekadashiList,
    required String currentLanguage,
  }) async {
    await initialize();

    final List<SearchIndexEntry> entries = [];
    final labels = lookupAppLocalizations(Locale(currentLanguage));
    final now = DateTime.now().toUtc().toIso8601String();

    // 1. EKADASHI (From current Ekadashi calculation/data)
    for (final e in ekadashiList) {
      final dateStr =
          '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}';
      entries.add(
        SearchIndexEntry(
          id: 'ekadashi_${e.id}',
          contentType: SearchContentType.ekadashi,
          title: e.name,
          normalizedTitle: _normalize(e.name),
          description: e.description,
          normalizedText: _normalize(
            '${e.name} ${e.description} ${e.paksha} ${e.month} ${e.benefits}',
          ),
          keywords: [
            'ekadashi',
            'vrat',
            'fasting',
            e.name.toLowerCase(),
            e.paksha.toLowerCase(),
            e.month.toLowerCase(),
            'parana',
          ],
          language: currentLanguage,
          date: dateStr,
          tags: [e.paksha, e.month, 'Ekadashi', 'Vrat'],
          sourceId: e.id.toString(),
          isDownloaded: true,
          isOnlineOnly: false,
          updatedAtUTC: now,
          navigationTarget: 'ekadashi_detail',
          metadata: {
            'ekadashi_id': e.id,
            'occurrence_uid': e.occurrenceUid,
            'year': e.date.year,
            'name': e.name,
            'date': dateStr,
            'paksha': e.paksha,
            'month': e.month,
            'fastStartTime': e.fastStartTime,
            'fastBreakTime': e.fastBreakTime,
            'benefits': e.benefits,
          },
        ),
      );

      // 2. KATHA (Stories for each Ekadashi)
      if (e.story.isNotEmpty) {
        entries.add(
          SearchIndexEntry(
            id: 'katha_${e.id}',
            contentType: SearchContentType.katha,
            title: '${e.name} ${labels.category_katha}',
            normalizedTitle: _normalize(
              '${e.name} ${labels.category_katha} Story',
            ),
            description: e.story.length > 180
                ? '${e.story.substring(0, 180)}...'
                : e.story,
            normalizedText: _normalize(
              '${e.name} ${labels.category_katha} Story ${e.story}',
            ),
            keywords: [
              'katha',
              'story',
              'history',
              'significance',
              e.name.toLowerCase(),
            ],
            language: currentLanguage,
            date: dateStr,
            tags: ['Katha', 'Story', e.name],
            sourceId: e.id.toString(),
            isDownloaded: true,
            isOnlineOnly: false,
            updatedAtUTC: now,
            navigationTarget: 'katha_detail',
            metadata: {
              'ekadashi_id': e.id,
              'occurrence_uid': e.occurrenceUid,
              'year': e.date.year,
              'title': '${e.name} ${labels.category_katha}',
              'full_story': e.story,
              'name': e.name,
              'date': dateStr,
            },
          ),
        );
      }

      // 5. VRAT INFORMATION (Rules for each Ekadashi)
      if (e.fastingRules.isNotEmpty) {
        entries.add(
          SearchIndexEntry(
            id: 'vrat_info_${e.id}',
            contentType: SearchContentType.vratInfo,
            title: '${e.name} ${labels.fasting_rules}',
            normalizedTitle: _normalize(
              '${e.name} ${labels.fasting_rules} Fasting Guidelines',
            ),
            description: e.fastingRules.length > 180
                ? '${e.fastingRules.substring(0, 180)}...'
                : e.fastingRules,
            normalizedText: _normalize(
              '${e.name} ${labels.fasting_rules} Fasting ${e.fastingRules}',
            ),
            keywords: [
              'vrat',
              'rules',
              'fasting rules',
              'guidelines',
              'parana',
              e.name.toLowerCase(),
            ],
            language: currentLanguage,
            date: dateStr,
            tags: ['Vrat Info', 'Rules', 'Fasting'],
            sourceId: e.id.toString(),
            isDownloaded: true,
            isOnlineOnly: false,
            updatedAtUTC: now,
            navigationTarget: 'vrat_detail',
            metadata: {
              'ekadashi_id': e.id,
              'occurrence_uid': e.occurrenceUid,
              'year': e.date.year,
              'title': '${e.name} ${labels.fasting_rules}',
              'rules': e.fastingRules,
              'name': e.name,
            },
          ),
        );
      }
    }

    // Add static curated catalog for Mantras, Food, Vrat Info, Festivals, Temples, Events, and Online Kathas
    entries.addAll(_getCuratedCatalog(now));

    return entries;
  }

  /// Curated catalog items across Mantra, Food, Vrat, Festival, Temple, Event, and Online content
  List<SearchIndexEntry> _getCuratedCatalog(String now) {
    final List<SearchIndexEntry> items = [];

    // Helper to evaluate download status
    bool isDownloaded(String id, bool defaultDownloaded) {
      if (_downloadedIds.contains(id)) return true;
      return defaultDownloaded;
    }

    // ---------------------------------------------------------
    // 2. KATHA (Online Extended Sacred Stories)
    // ---------------------------------------------------------
    const kathaOnline1 = 'katha_online_pandava';
    items.add(
      SearchIndexEntry(
        id: kathaOnline1,
        contentType: SearchContentType.katha,
        title: 'Pandava Nirjala Ekadashi Mahatmyam',
        normalizedTitle: _normalize(
          'Pandava Nirjala Ekadashi Mahatmyam Vyasa Bhima Story',
        ),
        description:
            'Complete sacred conversation between Sage Vyasadeva and Bhimasena detailing why waterless fasting on Nirjala grants the fruit of all 24 Ekadashis.',
        normalizedText: _normalize(
          'Pandava Nirjala Ekadashi Mahatmyam Vyasadeva Bhima waterless fast 24 ekadashi fruit vrkodara',
        ),
        keywords: [
          'pandava',
          'nirjala',
          'bhima',
          'katha',
          'vyasadeva',
          'waterless',
          'mahatmyam',
        ],
        language: 'en',
        tags: ['Katha', 'Mahatmyam', 'Nirjala'],
        sourceId: 'online_katha_1',
        isDownloaded: isDownloaded(kathaOnline1, false),
        isOnlineOnly: !isDownloaded(kathaOnline1, false),
        updatedAtUTC: now,
        navigationTarget: 'katha_detail',
        metadata: {
          'title': 'Pandava Nirjala Ekadashi Mahatmyam',
          'full_story':
              'When Bhimasena, the second son of Pandu, asked his grandfather Vyasadeva: "My mother Kunti, my brothers Yudhishthira, Arjuna, Nakula, Sahadeva, and Draupadi fast on every Ekadashi and urge me to fast as well. But O learned grandfather, the fire of Vrika burns in my belly and I cannot bear hunger! Tell me a fast by which I can attain the eternal spiritual world without daily torment."\n\nVyasadeva smiled and said: "Observe the waterless fast of the Shukla Paksha Ekadashi of Jyeshtha month. In this fast, not even a drop of water should pass down the throat, except for Achamana during rituals. By observing this single waterless fast with total surrender to Lord Janardana, one attains the merit and spiritual purification of all 24 Ekadashis of the year."',
          'source': 'Brahma Vaivarta Purana',
        },
      ),
    );

    const kathaOnline2 = 'katha_online_vaikuntha';
    items.add(
      SearchIndexEntry(
        id: kathaOnline2,
        contentType: SearchContentType.katha,
        title: 'Vaikuntha Ekadashi Celestial Gate Story',
        normalizedTitle: _normalize(
          'Vaikuntha Ekadashi Celestial Gate Story Mukkoti Vaikuntha Dvara',
        ),
        description:
            'The ancient pastime of the two demons Madhu and Kaitabha asking Lord Vishnu for liberation and opening the Vaikuntha Dvara for all mortals.',
        normalizedText: _normalize(
          'Vaikuntha Ekadashi Celestial Gate Story Mukkoti Vaikuntha Dvara Madhu Kaitabha Vishnu liberation heaven',
        ),
        keywords: [
          'vaikuntha',
          'celestial',
          'gate',
          'dvara',
          'mukkoti',
          'katha',
          'madhu',
          'kaitabha',
        ],
        language: 'en',
        tags: ['Katha', 'Vaikuntha', 'Mukkoti'],
        sourceId: 'online_katha_2',
        isDownloaded: isDownloaded(kathaOnline2, false),
        isOnlineOnly: !isDownloaded(kathaOnline2, false),
        updatedAtUTC: now,
        navigationTarget: 'katha_detail',
        metadata: {
          'title': 'Vaikuntha Ekadashi Celestial Gate Story',
          'full_story':
              'According to the Padma Purana, two demons named Madhu and Kaitabha received the divine grace of Lord Vishnu. Before departing to the spiritual sky, they requested the Lord: "O Bhagavan, whoever passes through the northern gate of your temple on this sacred Ekadashi day, and listens to this pastime, should be granted freedom from the cycle of birth and death." Lord Vishnu granted this boon, inaugurating the glorious Vaikuntha Dvara ceremony celebrated to this day.',
          'source': 'Padma Purana',
        },
      ),
    );

    // ---------------------------------------------------------
    // 3. MANTRA (Sacred Chants & Hymns)
    // ---------------------------------------------------------
    items.add(
      SearchIndexEntry(
        id: 'mantra_hare_krishna',
        contentType: SearchContentType.mantra,
        title: 'Hare Krishna Maha Mantra',
        normalizedTitle: _normalize(
          'Hare Krishna Maha Mantra Chanting Kali Yuga',
        ),
        description:
            'Hare Krishna Hare Krishna Krishna Krishna Hare Hare | Hare Rama Hare Rama Rama Rama Hare Hare. The supreme chant prescribed for purification on Ekadashi.',
        normalizedText: _normalize(
          'Hare Krishna Maha Mantra Hare Rama Kali Santarana Upanishad Chanting 108 japa mala',
        ),
        keywords: [
          'mantra',
          'hare krishna',
          'maha mantra',
          'chant',
          'japa',
          'krishna',
          'rama',
        ],
        language: 'en',
        tags: ['Mantra', 'Maha Mantra', 'Japa'],
        sourceId: 'mantra_1',
        isDownloaded: true,
        isOnlineOnly: false,
        updatedAtUTC: now,
        navigationTarget: 'mantra_detail',
        metadata: {
          'title': 'Hare Krishna Maha Mantra',
          'sanskrit':
              'हरे कृष्ण हरे कृष्ण कृष्ण कृष्ण हरे हरे ।\nहरे राम हरे राम राम राम हरे हरे ॥',
          'transliteration':
              'Hare Kṛṣṇa Hare Kṛṣṇa Kṛṣṇa Kṛṣṇa Hare Hare |\nHare Rāma Hare Rāma Rāma Rāma Hare Hare ||',
          'meaning':
              'O supreme energy of the Lord (Hare), O all-attractive Lord (Krishna), O source of all pleasure (Rama), please engage me in Your devotional service.',
          'benefits':
              'Purifies the heart, frees the practitioner from past karma, and awakens divine love of Godhead. Chanting 16 rounds on Ekadashi yields thousandfold merit.',
          'source': 'Kali-Saṇṭāraṇa Upaniṣad',
        },
      ),
    );

    items.add(
      SearchIndexEntry(
        id: 'mantra_om_namo_bhagavate',
        contentType: SearchContentType.mantra,
        title: 'Om Namo Bhagavate Vasudevaya',
        normalizedTitle: _normalize(
          'Om Namo Bhagavate Vasudevaya Dvadasaksara Mantra',
        ),
        description:
            'The sacred twelve-syllable (Dvadasaksara) mantra of Lord Vasudeva Krishna chanted during Ekadashi puja, japa, and arati.',
        normalizedText: _normalize(
          'Om Namo Bhagavate Vasudevaya Vishnu Krishna Dvadasaksara mantra liberation salvation',
        ),
        keywords: [
          'mantra',
          'om namo bhagavate vasudevaya',
          'dvadasaksara',
          'vishnu',
          'vasudeva',
          'chant',
        ],
        language: 'en',
        tags: ['Mantra', 'Dvadasaksara', 'Vishnu'],
        sourceId: 'mantra_2',
        isDownloaded: true,
        isOnlineOnly: false,
        updatedAtUTC: now,
        navigationTarget: 'mantra_detail',
        metadata: {
          'title': 'Om Namo Bhagavate Vasudevaya',
          'sanskrit': 'ॐ नमो भगवते वासुदेवाय ॥',
          'transliteration': 'Oṁ Namo Bhagavate Vāsudevāya ||',
          'meaning':
              'I bow to the Supreme Lord Vasudeva, who is present everywhere and in all living beings.',
          'benefits':
              'Removes planetary afflictions, destroys the fear of death, and grants moksha (liberation).',
          'source': 'Srimad Bhagavatam',
        },
      ),
    );

    items.add(
      SearchIndexEntry(
        id: 'mantra_parana_sloka',
        contentType: SearchContentType.mantra,
        title: 'Ekadashi Parana Breaking-Fast Mantra',
        normalizedTitle: _normalize(
          'Ekadashi Parana Mantra Ajnana timirandhasya',
        ),
        description:
            'Essential prayer chanted with sacred water and Tulsi leaf before taking first bite of food during the Parana window.',
        normalizedText: _normalize(
          'Ekadashi Parana Mantra Ajnana timirandhasya vratena anena kesava pranam breaking fast',
        ),
        keywords: [
          'parana',
          'mantra',
          'break fast',
          'prayer',
          'tulsi',
          'water',
          'timing',
        ],
        language: 'en',
        tags: ['Mantra', 'Parana', 'Prayer'],
        sourceId: 'mantra_3',
        isDownloaded: true,
        isOnlineOnly: false,
        updatedAtUTC: now,
        navigationTarget: 'mantra_detail',
        metadata: {
          'title': 'Ekadashi Parana Mantra',
          'sanskrit':
              'अज्ञानतिमिरान्धस्य व्रतेनानेन केशव ।\nप्रसीद सुमुखो नाथ ज्ञानदृष्टिप्रदो भव ॥',
          'transliteration':
              'Ajñāna-timirāndhasya vratenānena keśava |\nPrasīda sumukho nātha jñāna-dṛṣṭi-prado bhava ||',
          'meaning':
              'O Lord Keshava! I was blinded by the darkness of ignorance. By this fast, may You be pleased with me and bestow the vision of divine transcendental knowledge.',
          'benefits':
              'Validates the completion of the Ekadashi vow and sanctifies the fast-breaking meal.',
          'source': 'Hari-Bhakti-Vilasa',
        },
      ),
    );

    items.add(
      SearchIndexEntry(
        id: 'mantra_vishnu_sahasranama',
        contentType: SearchContentType.mantra,
        title: 'Vishnu Sahasranama Stotram',
        normalizedTitle: _normalize(
          'Vishnu Sahasranama Stotram Thousand Names of Lord Vishnu',
        ),
        description:
            'The 1,000 holy names of Lord Vishnu recited by Grandfather Bhishma on the battlefield of Kurukshetra. Traditionally chanted on Ekadashi.',
        normalizedText: _normalize(
          'Vishnu Sahasranama Stotram 1000 names Bhishma Mahabharata peace prosperity moksha',
        ),
        keywords: [
          'sahasranama',
          'vishnu',
          '1000 names',
          'bhishma',
          'stotram',
          'mantra',
        ],
        language: 'en',
        tags: ['Mantra', 'Sahasranama', 'Stotra'],
        sourceId: 'mantra_4',
        isDownloaded: true,
        isOnlineOnly: false,
        updatedAtUTC: now,
        navigationTarget: 'mantra_detail',
        metadata: {
          'title': 'Vishnu Sahasranama Stotram',
          'sanskrit':
              'शुक्लाम्बरधरं विष्णुं शशिवर्णं चतुर्भुजम् ।\nप्रसन्नवदनं ध्यायेत् सर्वविघ्नोपशान्तये ॥',
          'transliteration':
              'Śuklāmbaradharaṁ viṣṇuṁ śaśivarṇaṁ caturbhujam |\nPrasannavadanaṁ dhyāyet sarvavighnopaśāntaye ||',
          'meaning':
              'We meditate on Lord Vishnu, who wears pure white garments, has the radiance of the moon, possesses four arms, and has a benevolent countenance, for the pacification of all obstacles.',
          'benefits':
              'Removes sorrow, brings inner calm, protects against negative energies, and fulfills righteous desires.',
          'source': 'Mahabharata, Anushasana Parva',
        },
      ),
    );

    // ---------------------------------------------------------
    // 4. FOOD (Module 06 Food Guide)
    // ---------------------------------------------------------
    items.add(
      SearchIndexEntry(
        id: 'food_permitted_list',
        contentType: SearchContentType.food,
        title: 'Permitted Ekadashi Foods & Ingredients',
        normalizedTitle: _normalize(
          'Permitted Ekadashi Foods Ingredients Fruits Milk Ghee Sabudana Kuttu Sendha Namak',
        ),
        description:
            'Comprehensive guide to sattvic foods allowed during Ekadashi fasting: fresh fruits, milk, ghee, samak rice, buckwheat, sabudana, and rock salt.',
        normalizedText: _normalize(
          'Permitted Ekadashi Foods fruits milk curd ghee samak rice buckwheat kuttu sabudana tapioca singhara potatoes sweet potato sendha namak rock salt coconut almonds peanuts',
        ),
        keywords: [
          'food',
          'permitted',
          'ingredients',
          'sabudana',
          'kuttu',
          'samak',
          'fruits',
          'milk',
          'allowed',
        ],
        language: 'en',
        tags: ['Food', 'Permitted', 'Sattvic'],
        sourceId: 'food_1',
        isDownloaded: true,
        isOnlineOnly: false,
        updatedAtUTC: now,
        navigationTarget: 'food_detail',
        metadata: {
          'title': 'Permitted Ekadashi Foods',
          'category': 'Allowed / Sattvic',
          'items': [
            'Fresh Fruits (Apples, bananas, grapes, oranges, pomegranate, dates)',
            'Dairy Products (Pure cow milk, curd/yogurt, homemade paneer, pure desi ghee)',
            'Non-Cereal Grains (Samak rice / Barnyard millet, Kuttu / Buckwheat flour, Rajgira / Amaranth flour, Singhara / Water chestnut flour)',
            'Root Vegetables (Potatoes, sweet potatoes, raw banana, colocasia/arbi)',
            'Nuts & Seeds (Almonds, walnuts, cashews, peanuts, sesame seeds on designated days)',
            'Spices (Sendha namak / Rock salt, black pepper, ginger, fresh green coriander, cumin seeds)',
          ],
          'guidelines':
              'Prepare all meals in clean cookware untouched by grains or prohibited spices.',
        },
      ),
    );

    items.add(
      SearchIndexEntry(
        id: 'food_prohibited_list',
        contentType: SearchContentType.food,
        title: 'Prohibited Ekadashi Foods & Ingredients',
        normalizedTitle: _normalize(
          'Prohibited Ekadashi Foods Grains Wheat Rice Pulses Lentils Onion Garlic Mustard Hing',
        ),
        description:
            'Crucial checklist of ingredients strictly forbidden on Ekadashi: all grains, cereals, beans, lentils, onions, garlic, and table salt.',
        normalizedText: _normalize(
          'Prohibited Ekadashi Foods wheat rice barley oats corn lentils dal beans peas onions garlic hing asafoetida mustard seeds fenugreek table salt non-veg alcohol',
        ),
        keywords: [
          'food',
          'prohibited',
          'forbidden',
          'grains',
          'rice',
          'wheat',
          'dal',
          'onion',
          'garlic',
          'not allowed',
        ],
        language: 'en',
        tags: ['Food', 'Prohibited', 'Rules'],
        sourceId: 'food_2',
        isDownloaded: true,
        isOnlineOnly: false,
        updatedAtUTC: now,
        navigationTarget: 'food_detail',
        metadata: {
          'title': 'Prohibited Ekadashi Foods',
          'category': 'Forbidden / Tamasic & Rajasic',
          'items': [
            'All Grains & Cereals (Rice, wheat, maida, sooji, oats, barley, millet/bajra, corn, rye)',
            'All Pulses & Legumes (Toor dal, moong dal, chana dal, urad dal, rajma, chickpeas, lentils)',
            'Pungent Vegetables (Onions, garlic, leeks, shallots, mushrooms)',
            'Prohibited Spices (Mustard seeds, fenugreek/methi, asafoetida/hing, ordinary iodized table salt)',
            'Processed Products (Bakery breads, biscuits, commercial cornstarch, canned goods with additives)',
          ],
          'reason':
              'Scriptures state that on Ekadashi, all papas (demerit and karmic reactions) reside inside grains and pulses. Consuming them breaks the spiritual potency of the vow.',
        },
      ),
    );

    items.add(
      SearchIndexEntry(
        id: 'food_sabudana_khichdi',
        contentType: SearchContentType.food,
        title: 'Sabudana Khichdi Vrat Recipe',
        normalizedTitle: _normalize(
          'Sabudana Khichdi Vrat Recipe Tapioca Peanuts Sendha Namak Ghee',
        ),
        description:
            'Classic and nutritious non-grain Ekadashi dish made with soaked tapioca pearls, roasted peanuts, boiled potatoes, green chilies, and sendha namak.',
        normalizedText: _normalize(
          'Sabudana Khichdi Tapioca pearls peanuts potatoes green chilies ghee sendha namak recipe energy',
        ),
        keywords: [
          'food',
          'recipe',
          'sabudana',
          'khichdi',
          'peanuts',
          'tapioca',
          'cooking',
          'vrat food',
        ],
        language: 'en',
        tags: ['Food', 'Recipe', 'Sabudana'],
        sourceId: 'food_3',
        isDownloaded: true,
        isOnlineOnly: false,
        updatedAtUTC: now,
        navigationTarget: 'food_detail',
        metadata: {
          'title': 'Sabudana Khichdi Recipe',
          'category': 'Vrat Recipe',
          'ingredients':
              'Sabudana (1 cup soaked), roasted crushed peanuts (1/2 cup), boiled cubed potatoes (1 medium), green chilies (2), cumin seeds (1 tsp), ghee (2 tbsp), sendha namak to taste, fresh lemon juice and coriander.',
          'steps':
              '1. Heat pure ghee in a pan and temper cumin seeds and green chilies.\n2. Add boiled potatoes and saute until light golden.\n3. Add drained tapioca pearls, crushed peanuts, and sendha namak.\n4. Cook on low heat covered for 3-5 minutes until pearls turn translucent.\n5. Drizzle with lemon juice and garnish with fresh coriander.',
        },
      ),
    );

    const foodOnline1 = 'food_online_samak_pulao';
    items.add(
      SearchIndexEntry(
        id: foodOnline1,
        contentType: SearchContentType.food,
        title: 'Samak Rice Pulao (Barnyard Millet)',
        normalizedTitle: _normalize(
          'Samak Rice Pulao Barnyard Millet Mordhan Vrat Special',
        ),
        description:
            'Light, fragrant, and easy-to-digest grain-free pilaf made from Samak (barnyard millet) with cumin, cinnamon, and diced sweet potatoes.',
        normalizedText: _normalize(
          'Samak Rice Pulao Barnyard Millet Mordhan Vrat Special ghee sweet potato fasting recipe',
        ),
        keywords: [
          'food',
          'samak',
          'millet',
          'pulao',
          'mordhan',
          'grain-free',
          'recipe',
        ],
        language: 'en',
        tags: ['Food', 'Recipe', 'Samak'],
        sourceId: 'food_online_1',
        isDownloaded: isDownloaded(foodOnline1, false),
        isOnlineOnly: !isDownloaded(foodOnline1, false),
        updatedAtUTC: now,
        navigationTarget: 'food_detail',
        metadata: {
          'title': 'Samak Rice Pulao',
          'category': 'Online Recipe',
          'ingredients':
              '1 cup Samak rice (mordhan), 2 cups water, 1 tbsp ghee, 1 cinnamon stick, 2 cloves, diced sweet potato, sendha namak.',
          'steps':
              'Rinse Samak rice. In ghee, saute spices and diced potatoes. Add rice, water, and rock salt. Pressure cook for 1 whistle. Serve warm with plain yogurt.',
        },
      ),
    );

    // ---------------------------------------------------------
    // 5. VRAT INFORMATION (Rituals & Spiritual Guidelines)
    // ---------------------------------------------------------
    items.add(
      SearchIndexEntry(
        id: 'vrat_parana_rules',
        contentType: SearchContentType.vratInfo,
        title: 'Parana Timing & Fast-Breaking Window Rules',
        normalizedTitle: _normalize(
          'Parana Timing Fast Breaking Window Rules Hari Vasara Dvadoshi Sunrise',
        ),
        description:
            'Comprehensive guidelines on how and when to break the Ekadashi fast: why Parana must occur on Dvadoshi within the calculated window before sunrise closure.',
        normalizedText: _normalize(
          'Parana Timing Fast Breaking Window Rules Hari Vasara Dvadoshi Sunrise calculation time penalty prasad',
        ),
        keywords: [
          'vrat',
          'parana',
          'timing',
          'window',
          'hari vasara',
          'dvadoshi',
          'rules',
          'break fast',
        ],
        language: 'en',
        tags: ['Vrat Info', 'Parana', 'Timings'],
        sourceId: 'vrat_1',
        isDownloaded: true,
        isOnlineOnly: false,
        updatedAtUTC: now,
        navigationTarget: 'vrat_detail',
        metadata: {
          'title': 'Parana Timing & Fast-Breaking Rules',
          'key_rules': [
            'Parana must be observed on Dvadoshi tithi after sunrise and before the Parana window end time.',
            'Never break the fast during Hari Vasara (the first quarter of Dvadoshi tithi).',
            'If Dvadoshi ends before sunrise, Parana should be done on Trayodashi morning immediately after sunrise.',
            'Breaking the fast with pure water containing a Tulsi leaf or Charanāmrita is the most auspicious method.',
            'Avoid heavy or oily meals immediately upon breaking the fast.',
          ],
          'importance':
              'Failure to break the fast within the designated Parana window destroys the spiritual merit accumulated during Ekadashi.',
        },
      ),
    );

    items.add(
      SearchIndexEntry(
        id: 'vrat_three_day_discipline',
        contentType: SearchContentType.vratInfo,
        title: 'The 3-Day Ekadashi Fasting Discipline',
        normalizedTitle: _normalize(
          'The 3 Day Ekadashi Fasting Discipline Dashami Ekadashi Dvadoshi Rules',
        ),
        description:
            'The complete traditional code of conduct spanning Dashami (preparation), Ekadashi (total devotion & vigil), and Dvadoshi (parana & charity).',
        normalizedText: _normalize(
          'Three day Ekadashi fasting discipline Dashami preparation Ekadashi vigil Dvadoshi parana charity conduct',
        ),
        keywords: [
          'vrat',
          'dashami',
          'dvadoshi',
          'discipline',
          'conduct',
          'fasting stages',
          'rules',
        ],
        language: 'en',
        tags: ['Vrat Info', 'Discipline', 'Guidelines'],
        sourceId: 'vrat_2',
        isDownloaded: true,
        isOnlineOnly: false,
        updatedAtUTC: now,
        navigationTarget: 'vrat_detail',
        metadata: {
          'title': 'The 3-Day Ekadashi Discipline',
          'stages': [
            'Day 1 (Dashami): Eat only one light sattvic meal during the afternoon. Avoid dinner. Maintain purity and calm mindset.',
            'Day 2 (Ekadashi): Observe fasting from sunrise to sunrise. Chant holy names, read spiritual texts, and observe night vigil (Jagarana) if possible.',
            'Day 3 (Dvadoshi): Bathe early, perform Vishnu worship, chant Parana mantra, break the fast during the Parana window, and feed Brahmins/guests.',
          ],
        },
      ),
    );

    items.add(
      SearchIndexEntry(
        id: 'vrat_types_classification',
        contentType: SearchContentType.vratInfo,
        title: 'Types of Ekadashi Fasts: Nirjala vs Phalahari',
        normalizedTitle: _normalize(
          'Types of Ekadashi Fasts Nirjala Jalahari Dugdhahari Phalahari Levels',
        ),
        description:
            'Detailed explanation of the 4 levels of Ekadashi fasting based on health, capacity, and scriptural recommendations.',
        normalizedText: _normalize(
          'Types of Ekadashi Fasts Nirjala without water Jalahari water only Dugdhahari milk only Phalahari fruits only',
        ),
        keywords: [
          'vrat',
          'types',
          'nirjala',
          'phalahari',
          'jalahari',
          'fasting levels',
          'health',
        ],
        language: 'en',
        tags: ['Vrat Info', 'Types', 'Fasting Levels'],
        sourceId: 'vrat_3',
        isDownloaded: true,
        isOnlineOnly: false,
        updatedAtUTC: now,
        navigationTarget: 'vrat_detail',
        metadata: {
          'title': '4 Levels of Ekadashi Fasting',
          'levels': [
            '1. Nirjala (Highest): No water or food from sunrise to next sunrise. Recommended on Jyeshtha Shukla Ekadashi.',
            '2. Jalahari: Consuming only water throughout the day. Suitable for healthy practitioners.',
            '3. Dugdhahari: Consuming only milk or dairy at intervals. Very purifying.',
            '4. Phalahari (General): Consuming fruits, nuts, and approved non-grain items once or twice.',
          ],
          'counsel':
              'Those with medical conditions, pregnancy, or elderly age should follow Phalahari fasting without guilt.',
        },
      ),
    );

    // ---------------------------------------------------------
    // 6. FESTIVAL (Sacred Vaishnava Festivals)
    // ---------------------------------------------------------
    items.add(
      SearchIndexEntry(
        id: 'fest_vaikuntha_ekadashi',
        contentType: SearchContentType.festival,
        title: 'Vaikuntha Ekadashi (Mukkoti)',
        normalizedTitle: _normalize(
          'Vaikuntha Ekadashi Mukkoti Margashirsha Dhanurmasam Vaikuntha Dvara',
        ),
        description:
            'The supreme festival observed during Dhanurmasam (Margashirsha). Temples open the northern Vaikuntha Dvara for devotees to receive direct salvation.',
        normalizedText: _normalize(
          'Vaikuntha Ekadashi Mukkoti Margashirsha Dhanurmasam Vaikuntha Dvara Srirangam Tirupati Vishnu paradise heaven festival',
        ),
        keywords: [
          'festival',
          'vaikuntha',
          'mukkoti',
          'dvara',
          'srirangam',
          'tirupati',
          'dhanurmasam',
        ],
        language: 'en',
        date: '2026-12-30',
        tags: ['Festival', 'Vaikuntha', 'Mukkoti'],
        sourceId: 'fest_1',
        isDownloaded: true,
        isOnlineOnly: false,
        updatedAtUTC: now,
        navigationTarget: 'festival_detail',
        metadata: {
          'title': 'Vaikuntha Ekadashi (Mukkoti)',
          'date': '2026-12-30',
          'significance':
              'The gates of Lord Vishnu’s celestial abode, Vaikuntha, are believed to be opened wide. Millions visit Srirangam and Tirumala to pass through the Paramapada Vasal.',
          'rituals':
              '24-hour complete fasting, pre-dawn darshanam at the northern gate, Veda recitation, and Akhanda bhajans.',
        },
      ),
    );

    items.add(
      SearchIndexEntry(
        id: 'fest_gita_jayanti',
        contentType: SearchContentType.festival,
        title: 'Gita Jayanti (Mokshada Ekadashi)',
        normalizedTitle: _normalize(
          'Gita Jayanti Mokshada Ekadashi Kurukshetra Krishna Arjuna Bhagavad Gita',
        ),
        description:
            'The historic day Lord Sri Krishna delivered the immortal message of Bhagavad Gita to Arjuna on the sacred field of Kurukshetra.',
        normalizedText: _normalize(
          'Gita Jayanti Mokshada Ekadashi Kurukshetra Krishna Arjuna Bhagavad Gita 18 chapters recitation philosophy',
        ),
        keywords: [
          'festival',
          'gita jayanti',
          'mokshada',
          'bhagavad gita',
          'krishna',
          'arjuna',
          'kurukshetra',
        ],
        language: 'en',
        date: '2026-12-20',
        tags: ['Festival', 'Gita Jayanti', 'Bhagavad Gita'],
        sourceId: 'fest_2',
        isDownloaded: true,
        isOnlineOnly: false,
        updatedAtUTC: now,
        navigationTarget: 'festival_detail',
        metadata: {
          'title': 'Gita Jayanti (Mokshada Ekadashi)',
          'date': '2026-12-20',
          'significance':
              'Celebrating the birth of Srimad Bhagavad Gita, the world’s greatest philosophical dialogue on dharma, karma, and bhakti.',
          'rituals':
              'Recitation of all 700 verses across 18 chapters, mass distribution of Gita, Gita homa, and Ekadashi fasting.',
        },
      ),
    );

    items.add(
      SearchIndexEntry(
        id: 'fest_devshayani_ekadashi',
        contentType: SearchContentType.festival,
        title: 'Devshayani Ekadashi (Chaturmasya Begins)',
        normalizedTitle: _normalize(
          'Devshayani Ekadashi Ashadha Shukla Chaturmasya Beginning Lord Vishnu Sleep',
        ),
        description:
            'The auspicious day when Lord Vishnu enters deep yogic slumber (Yoga Nidra) in the cosmic ocean on Shesha Naga for four months.',
        normalizedText: _normalize(
          'Devshayani Ekadashi Ashadha Shukla Chaturmasya Beginning Lord Vishnu Sleep Ksheer Sagara Yoga Nidra vows',
        ),
        keywords: [
          'festival',
          'devshayani',
          'chaturmasya',
          'yoga nidra',
          'ashadha',
          'vow',
        ],
        language: 'en',
        date: '2026-07-25',
        tags: ['Festival', 'Chaturmasya', 'Devshayani'],
        sourceId: 'fest_3',
        isDownloaded: true,
        isOnlineOnly: false,
        updatedAtUTC: now,
        navigationTarget: 'festival_detail',
        metadata: {
          'title': 'Devshayani Ekadashi',
          'date': '2026-07-25',
          'significance':
              'Marks the commencement of the four-month rainy season spiritual penance (Chaturmasya). Auspicious secular ceremonies like weddings pause.',
          'rituals':
              'Initiation of 4-month vows, intense scripture reading, charity, and offering yellow silks to Lord Vishnu.',
        },
      ),
    );

    items.add(
      SearchIndexEntry(
        id: 'fest_devutthana_ekadashi',
        contentType: SearchContentType.festival,
        title: 'Devutthana / Prabodhini Ekadashi (Tulsi Vivah)',
        normalizedTitle: _normalize(
          'Devutthana Prabodhini Ekadashi Kartika Shukla Tulsi Vivah Waking of Vishnu',
        ),
        description:
            'Lord Vishnu awakens from his 4-month cosmic slumber. Concludes Chaturmasya and celebrates the divine wedding of Tulsi Devi with Lord Shaligram.',
        normalizedText: _normalize(
          'Devutthana Prabodhini Ekadashi Kartika Shukla Tulsi Vivah Waking of Vishnu Shaligram wedding festival',
        ),
        keywords: [
          'festival',
          'devutthana',
          'prabodhini',
          'tulsi vivah',
          'shaligram',
          'kartika',
          'chaturmasya end',
        ],
        language: 'en',
        date: '2026-11-20',
        tags: ['Festival', 'Tulsi Vivah', 'Prabodhini'],
        sourceId: 'fest_4',
        isDownloaded: true,
        isOnlineOnly: false,
        updatedAtUTC: now,
        navigationTarget: 'festival_detail',
        metadata: {
          'title': 'Devutthana Ekadashi & Tulsi Vivah',
          'date': '2026-11-20',
          'significance':
              'Conclusion of Chaturmasya vows. Holy marriage of Tulsi Devi with Lord Shaligram brings wedding season back to life.',
          'rituals':
              'Sugarcane mandap creation, lighting 365 ghee lamps, Tulsi Vivah ceremony with bridal adornments and mangalsutra.',
        },
      ),
    );

    // ---------------------------------------------------------
    // 7. TEMPLE (Sacred Ekadashi Pilgrimage Temples)
    // ---------------------------------------------------------
    items.add(
      SearchIndexEntry(
        id: 'temple_srirangam',
        contentType: SearchContentType.temple,
        title: 'Sri Ranganathaswamy Temple, Srirangam',
        normalizedTitle: _normalize(
          'Sri Ranganathaswamy Temple Srirangam Tamil Nadu Divya Desam Vaikuntha Dvara',
        ),
        description:
            'The foremost of the 108 Divya Desams situated on an island in the Kaveri river. Famed for its monumental 21-day Vaikuntha Ekadashi Mahotsavam.',
        normalizedText: _normalize(
          'Sri Ranganathaswamy Temple Srirangam Tamil Nadu Divya Desam Vaikuntha Dvara Ranganatha Paramapada Vasal Kaveri island',
        ),
        keywords: [
          'temple',
          'srirangam',
          'ranganatha',
          'divya desam',
          'tamil nadu',
          'paramapada vasal',
        ],
        language: 'en',
        tags: ['Temple', 'Divya Desam', 'Srirangam'],
        sourceId: 'temple_1',
        isDownloaded: true,
        isOnlineOnly: false,
        updatedAtUTC: now,
        navigationTarget: 'temple_detail',
        metadata: {
          'name': 'Sri Ranganathaswamy Temple',
          'location': 'Srirangam, Tiruchirappalli, Tamil Nadu',
          'deity':
              'Sri Ranganatha (Lord Vishnu in reclining posture / Sayana Murti)',
          'highlights':
              'Largest functioning Hindu temple complex in the world. On Vaikuntha Ekadashi, the deity moves through the sacred Paramapada Vasal in golden armor.',
        },
      ),
    );

    items.add(
      SearchIndexEntry(
        id: 'temple_tirumala',
        contentType: SearchContentType.temple,
        title: 'Sri Venkateswara Swamy Temple, Tirumala',
        normalizedTitle: _normalize(
          'Sri Venkateswara Swamy Temple Tirumala Tirupati Andhra Pradesh Vaikuntha Dvara',
        ),
        description:
            'The world-famous sacred shrine atop the Seven Hills in Tirupati. Renowned for ten days of Vaikuntha Dvara Darshanam opening on Vaikuntha Ekadashi.',
        normalizedText: _normalize(
          'Sri Venkateswara Swamy Temple Tirumala Tirupati Andhra Pradesh Vaikuntha Dvara Balaji Govinda Seven Hills Saptagiri',
        ),
        keywords: [
          'temple',
          'tirumala',
          'tirupati',
          'venkateswara',
          'balaji',
          'andhra pradesh',
          'seven hills',
        ],
        language: 'en',
        tags: ['Temple', 'Tirumala', 'Venkateswara'],
        sourceId: 'temple_2',
        isDownloaded: true,
        isOnlineOnly: false,
        updatedAtUTC: now,
        navigationTarget: 'temple_detail',
        metadata: {
          'name': 'Sri Venkateswara Temple',
          'location': 'Tirumala Hills, Tirupati, Andhra Pradesh',
          'deity': 'Lord Venkateswara (Kali Yuga Varada)',
          'highlights':
              'Vaikuntha Dvara circumambulation path opened exclusively for 10 days starting Vaikuntha Ekadashi morning.',
        },
      ),
    );

    items.add(
      SearchIndexEntry(
        id: 'temple_pandharpur',
        contentType: SearchContentType.temple,
        title: 'Vitthal Rukmini Temple, Pandharpur',
        normalizedTitle: _normalize(
          'Vitthal Rukmini Temple Pandharpur Maharashtra Varkari Ashadhi Kartiki Ekadashi',
        ),
        description:
            'The epic spiritual epicenter on the banks of Chandrabhaga river in Maharashtra. Millions of Varkaris converge here on Ashadhi and Kartiki Ekadashi.',
        normalizedText: _normalize(
          'Vitthal Rukmini Temple Pandharpur Maharashtra Varkari Ashadhi Kartiki Ekadashi Vithoba Tukaram Dnyaneshwar Wari',
        ),
        keywords: [
          'temple',
          'pandharpur',
          'vitthal',
          'vithoba',
          'maharashtra',
          'ashadhi',
          'kartiki',
          'wari',
        ],
        language: 'en',
        tags: ['Temple', 'Pandharpur', 'Vitthal'],
        sourceId: 'temple_3',
        isDownloaded: true,
        isOnlineOnly: false,
        updatedAtUTC: now,
        navigationTarget: 'temple_detail',
        metadata: {
          'name': 'Vitthal Rukmini Temple',
          'location': 'Pandharpur, Solapur, Maharashtra',
          'deity': 'Lord Vitthal (Vithoba) and Rukmini',
          'highlights':
              'Destination of the 800-year-old annual Wari pilgrimage where devotees walk 250+ km chanting Harinama.',
        },
      ),
    );

    const templeOnline1 = 'temple_online_guruvayur';
    items.add(
      SearchIndexEntry(
        id: templeOnline1,
        contentType: SearchContentType.temple,
        title: 'Guruvayur Sri Krishna Temple, Kerala',
        normalizedTitle: _normalize(
          'Guruvayur Sri Krishna Temple Kerala Bhuloka Vaikuntha Guruvayur Ekadashi',
        ),
        description:
            'Known as Bhuloka Vaikuntha (heaven on earth). Celebrates Guruvayur Ekadashi with grand elephant procession (Vilakku) and Chembai music festival.',
        normalizedText: _normalize(
          'Guruvayur Sri Krishna Temple Kerala Bhuloka Vaikuntha Guruvayur Ekadashi Vilakku Chembai music festival',
        ),
        keywords: [
          'temple',
          'guruvayur',
          'kerala',
          'krishna',
          'guruvayurappan',
          'bhuloka vaikuntha',
        ],
        language: 'en',
        tags: ['Temple', 'Guruvayur', 'Kerala'],
        sourceId: 'temple_online_1',
        isDownloaded: isDownloaded(templeOnline1, false),
        isOnlineOnly: !isDownloaded(templeOnline1, false),
        updatedAtUTC: now,
        navigationTarget: 'temple_detail',
        metadata: {
          'name': 'Guruvayur Temple',
          'location': 'Guruvayur, Thrissur, Kerala',
          'deity': 'Lord Guruvayurappan (Child Krishna with four arms)',
          'highlights':
              'Guruvayur Ekadashi features Udayasthamana puja and lighting of 30,000 stone lamps on the temple exterior.',
        },
      ),
    );

    // ---------------------------------------------------------
    // 8. EVENT (Module 15 Pilgrimage & Community Events)
    // ---------------------------------------------------------
    items.add(
      SearchIndexEntry(
        id: 'event_pandharpur_wari',
        contentType: SearchContentType.event,
        title: 'Pandharpur Wari Palkhi Pilgrimage',
        normalizedTitle: _normalize(
          'Pandharpur Wari Palkhi Pilgrimage Sant Tukaram Dnyaneshwar Ashadhi Ekadashi Walk',
        ),
        description:
            '21-day walking spiritual odyssey of over 1 million devotees singing abhangas across Maharashtra, culminating at Pandharpur on Ashadhi Ekadashi.',
        normalizedText: _normalize(
          'Pandharpur Wari Palkhi Pilgrimage Sant Tukaram Dnyaneshwar Ashadhi Ekadashi Walk varkari kirtan',
        ),
        keywords: [
          'event',
          'pilgrimage',
          'wari',
          'palkhi',
          'pandharpur',
          'ashadhi ekadashi',
          'walk',
        ],
        language: 'en',
        date: '2026-07-25',
        tags: ['Event', 'Pilgrimage', 'Wari'],
        sourceId: 'event_1',
        isDownloaded: true,
        isOnlineOnly: false,
        updatedAtUTC: now,
        navigationTarget: 'event_detail',
        metadata: {
          'title': 'Pandharpur Wari Palkhi Pilgrimage',
          'date': '2026-07-05 to 2026-07-25',
          'location': 'Dehu/Alandi to Pandharpur, Maharashtra',
          'highlights':
              'UNESCO-recognized living spiritual tradition. 1,000,000+ pilgrims walk 250 kilometers chanting "Gyanba Tukaram".',
        },
      ),
    );

    items.add(
      SearchIndexEntry(
        id: 'event_akhanda_sankirtana',
        contentType: SearchContentType.event,
        title: '24-Hour Akhanda Harinama Sankirtana',
        normalizedTitle: _normalize(
          '24 Hour Akhanda Harinama Sankirtana All night Vigil Jagarana Ekadashi Chanting',
        ),
        description:
            'Non-stop devotional congregational chanting of the holy names from sunrise to sunrise on Ekadashi with mridanga and kartals.',
        normalizedText: _normalize(
          '24 Hour Akhanda Harinama Sankirtana All night Vigil Jagarana Ekadashi Chanting mridanga kartal bhajans',
        ),
        keywords: [
          'event',
          'sankirtana',
          'akhanda',
          'harinama',
          'chanting',
          'jagarana',
          '24 hour',
        ],
        language: 'en',
        tags: ['Event', 'Kirtan', 'Jagarana'],
        sourceId: 'event_2',
        isDownloaded: true,
        isOnlineOnly: false,
        updatedAtUTC: now,
        navigationTarget: 'event_detail',
        metadata: {
          'title': '24-Hour Akhanda Sankirtana',
          'description':
              'Devotees take turns chanting in 2-hour shifts through the night, fulfilling the scriptural injunction of Ekadashi Jagarana (night vigil).',
        },
      ),
    );

    const eventOnline1 = 'event_online_gita_recitation';
    items.add(
      SearchIndexEntry(
        id: eventOnline1,
        contentType: SearchContentType.event,
        title: 'Global Gita Jayanti Mass Recitation',
        normalizedTitle: _normalize(
          'Global Gita Jayanti Mass Recitation Mokshada Ekadashi Worldwide Chanting',
        ),
        description:
            'Worldwide simultaneous recitation of all 700 Bhagavad Gita verses on Mokshada Ekadashi day across 50+ countries.',
        normalizedText: _normalize(
          'Global Gita Jayanti Mass Recitation Mokshada Ekadashi Worldwide Chanting 700 verses Kurukshetra international',
        ),
        keywords: [
          'event',
          'gita jayanti',
          'recitation',
          'worldwide',
          'international',
          'mokshada',
        ],
        language: 'en',
        date: '2026-12-20',
        tags: ['Event', 'Gita Jayanti', 'Global'],
        sourceId: 'event_online_1',
        isDownloaded: isDownloaded(eventOnline1, false),
        isOnlineOnly: !isDownloaded(eventOnline1, false),
        updatedAtUTC: now,
        navigationTarget: 'event_detail',
        metadata: {
          'title': 'Global Gita Jayanti Mass Recitation',
          'date': '2026-12-20',
          'location': 'Worldwide (Virtual & Temples)',
          'organizers': 'International Gita Forums & Temple Networks',
        },
      ),
    );

    return items;
  }

  /// String normalization for indexing and query matching (lowercase, stripped punctuation, extra whitespace)
  String _normalize(String text) => normalizeSearchText(text);
}
