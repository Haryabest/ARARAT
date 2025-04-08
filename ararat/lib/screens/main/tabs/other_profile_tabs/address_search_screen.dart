import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddressSearchScreen extends StatefulWidget {
  final Function(LatLng location, String address) onAddressSelected;

  const AddressSearchScreen({
    super.key,
    required this.onAddressSelected,
  });

  @override
  State<AddressSearchScreen> createState() => _AddressSearchScreenState();
}

class _AddressSearchScreenState extends State<AddressSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<AddressResult> _searchResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.requestFocus();
    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    if (_searchController.text.length > 2) {
      _searchAddress(_searchController.text);
    } else {
      setState(() {
        _searchResults = [];
      });
    }
  }

  Future<void> _searchAddress(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Формируем URL для запроса к API OpenStreetMap Nominatim
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=json&q=$query&addressdetails=1&limit=10&accept-language=ru&countrycodes=ru');

      // Делаем запрос
      final response = await http.get(url, headers: {
        'User-Agent': 'ARARAT-App/1.0',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<AddressResult> results = [];

        for (var item in data) {
          try {
            final double lat = double.parse(item['lat']);
            final double lon = double.parse(item['lon']);
            final displayName = item['display_name'] as String;

            var formattedAddress = displayName;
            String city = '';
            String street = '';
            String houseNumber = '';

            if (item.containsKey('address')) {
              final address = item['address'];
              final List<String> addressParts = [];

              // Город
              if (address.containsKey('city')) {
                city = address['city'];
                addressParts.add(address['city']);
              } else if (address.containsKey('town')) {
                city = address['town'];
                addressParts.add(address['town']);
              } else if (address.containsKey('village')) {
                city = address['village'];
                addressParts.add(address['village']);
              }

              // Улица
              if (address.containsKey('road')) {
                street = address['road'];
                addressParts.add(address['road']);
              }

              // Номер дома
              if (address.containsKey('house_number')) {
                houseNumber = address['house_number'];
                addressParts.add('дом ${address['house_number']}');
              }

              if (addressParts.isNotEmpty) {
                formattedAddress = addressParts.join(', ');
              }
            }

            results.add(AddressResult(
              location: LatLng(lat, lon),
              fullAddress: displayName,
              formattedAddress: formattedAddress,
              city: city,
              street: street,
              houseNumber: houseNumber,
            ));
          } catch (e) {
          }
        }

        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
    });
  }

  void _selectAddress(AddressResult result) {
    widget.onAddressSelected(result.location, result.formattedAddress);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFA99378),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Padding(
            padding: EdgeInsets.all(12.0),
            child: Icon(Icons.arrow_back_ios, color: Color(0xFFFFFFFF)),
          ),
        ),
        title: const Text(
          'Поиск адреса',
          style: TextStyle(
            color: Color(0xFFFFFFFF),
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Строка поиска
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Введите адрес для поиска',
                  hintStyle: const TextStyle(
                    color: Color(0xFFA2A2A2),
                    fontFamily: 'Inter',
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF50321B),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? GestureDetector(
                          onTap: _clearSearch,
                          child: const Icon(
                            Icons.close,
                            color: Color(0xFF50321B),
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),

          // Результаты поиска
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF50321B),
                    ),
                  )
                : _searchResults.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.length <= 2
                              ? 'Введите не менее 3 символов для поиска'
                              : 'Нет результатов поиска',
                          style: const TextStyle(
                            color: Color(0xFFFFFFFF),
                            fontFamily: 'Inter',
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) => const Divider(
                          color: Color(0xFFE0D5C9),
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final result = _searchResults[index];
                          return GestureDetector(
                            onTap: () => _selectAddress(result),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12.0,
                                horizontal: 8.0,
                              ),
                              color: Colors.transparent,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    color: Color(0xFF50321B),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          result.formattedAddress,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFFFFFFFF),
                                          ),
                                        ),
                                        if (result.fullAddress != result.formattedAddress)
                                          Text(
                                            result.fullAddress,
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 12,
                                              color: Color(0xFFE0D5C9),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class AddressResult {
  final LatLng location;
  final String fullAddress;
  final String formattedAddress;
  final String city;
  final String street;
  final String houseNumber;

  AddressResult({
    required this.location,
    required this.fullAddress,
    required this.formattedAddress,
    this.city = '',
    this.street = '',
    this.houseNumber = '',
  });
} 