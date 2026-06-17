import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horoscope/core/constants/app_colors.dart';
import 'package:horoscope/core/constants/app_text_styles.dart';
import 'package:horoscope/core/providers/language_provider.dart';
import 'package:horoscope/core/utils/birth_place_data.dart';

class BirthPlaceSearchSheet extends ConsumerStatefulWidget {
  const BirthPlaceSearchSheet({super.key});

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => const BirthPlaceSearchSheet(),
    );
  }

  @override
  ConsumerState<BirthPlaceSearchSheet> createState() => _BirthPlaceSearchSheetState();
}

class _BirthPlaceSearchSheetState extends ConsumerState<BirthPlaceSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<PlaceItem> _filteredPlaces = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _filteredPlaces = [];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = val.trim();
      if (_searchQuery.isEmpty) {
        _filteredPlaces = [];
      } else {
        _filteredPlaces = BirthPlaceData.allPlaces
            .where((item) => item.matches(_searchQuery))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(languageProvider);
    final isTr = locale.languageCode == 'tr';

    // Popüler varsayılanlar (Arama boşken)
    final popularPlaces = [
      const PlaceItem(nameTr: 'İstanbul', nameEn: 'Istanbul', isCity: true),
      const PlaceItem(nameTr: 'Ankara', nameEn: 'Ankara', isCity: true),
      const PlaceItem(nameTr: 'İzmir', nameEn: 'Izmir', isCity: true),
      const PlaceItem(nameTr: 'Türkiye', nameEn: 'Turkey'),
      const PlaceItem(nameTr: 'Almanya', nameEn: 'Germany'),
      const PlaceItem(nameTr: 'Amerika Birleşik Devletleri', nameEn: 'United States'),
      const PlaceItem(nameTr: 'Birleşik Krallık', nameEn: 'United Kingdom'),
    ];

    final displayList = _searchQuery.isEmpty ? popularPlaces : _filteredPlaces;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: AppColors.cardSurface.withValues(alpha: 0.92),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          border: Border.all(color: AppColors.borderLight, width: 1.5),
        ),
        padding: EdgeInsets.only(
          top: 16,
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sürükleme Çubuğu
            Center(
              child: Container(
                width: 48,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            // Başlık satırı
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isTr ? 'Doğum Yeri Seçin' : 'Select Birth Place',
                  style: AppTextStyles.h3.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Arama Çubuğu
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: isTr ? 'İl veya ülke adı yazın...' : 'Type city or country...',
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryGold),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: AppColors.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primaryGold, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Etiket
            Text(
              _searchQuery.isEmpty
                  ? (isTr ? 'Popüler Yerler' : 'Popular Places')
                  : (isTr ? 'Arama Sonuçları' : 'Search Results'),
              style: AppTextStyles.caption.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Sonuç Listesi
            Expanded(
              child: displayList.isEmpty
                  ? Center(
                      child: Text(
                        isTr ? 'Sonuç bulunamadı.' : 'No results found.',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      itemCount: displayList.length,
                      itemBuilder: (context, index) {
                        final item = displayList[index];
                        final displayName = isTr ? item.nameTr : item.nameEn;
                        
                        String subtitle = '';
                        if (item.isCity) {
                          subtitle = isTr ? 'Türkiye, İl / Şehir' : 'Turkey, Province / City';
                        } else {
                          subtitle = isTr ? 'Ülke' : 'Country';
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: item.isCity 
                                    ? AppColors.primaryGold.withValues(alpha: 0.15)
                                    : Colors.blueAccent.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                item.isCity ? Icons.location_city_rounded : Icons.public_rounded,
                                color: item.isCity ? AppColors.primaryGold : Colors.blueAccent,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              displayName,
                              style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              subtitle,
                              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                            ),
                            onTap: () {
                              Navigator.pop(context, displayName);
                            },
                          ),
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
