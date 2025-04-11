import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';

class MapScreen extends StatefulWidget {
  final Function(String address, LatLng location) onAddressSelected;

  const MapScreen({
    super.key,
    required this.onAddressSelected,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late MapController _mapController;
  final TextEditingController _searchController = TextEditingController();
  LatLng? _currentPosition;
  List<Marker> _markers = [];
  Timer? _debounce;
  List<Location> _searchResults = [];
  bool _isSearching = false;
  bool _isSearchLoading = false;
  bool _isLoading = true;
  bool _isConfirmLoading = false;
  bool _isConfirmingLocation = false;
  
  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _getCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF4B260A),
                  ),
                )
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentPosition ?? const LatLng(55.7558, 37.6173), // По умолчанию Москва
                    initialZoom: 15,
                    onTap: (tapPosition, latLng) {
                      setState(() {
                        _currentPosition = latLng;
                        _markers.clear();
                        _markers.add(
                          Marker(
                            point: latLng,
                            child: const Icon(
                              Icons.location_on,
                              color: Color(0xFF4B260A),
                              size: 40,
                            ),
                          ),
                        );
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.ararat',
                    ),
                    MarkerLayer(markers: _markers),
                  ],
                ),
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Поиск места...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        suffixIcon: _isSearchLoading 
                            ? Container(
                                padding: const EdgeInsets.all(10),
                                width: 20,
                                height: 20,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF4B260A),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.search),
                                onPressed: () {
                                  if (_searchController.text.isNotEmpty) {
                                    _searchLocation(_searchController.text);
                                  }
                                },
                              ),
                      ),
                      onChanged: _onSearchChanged,
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          _searchLocation(value);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.my_location),
                    onPressed: _getCurrentLocation,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
          if (_isSearching && _searchResults.isNotEmpty)
            Positioned(
              top: 100,
              left: 20,
              right: 20,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_searchResults[index].toString(), 
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      onTap: () => _selectSearchResult(_searchResults[index]),
                    );
                  },
                ),
              ),
            ),
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Column(
              children: [
                if (_currentPosition != null && _isConfirmingLocation)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF4B260A),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.pin_drop,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Подтвердите выбранную точку на карте',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ElevatedButton(
                  onPressed: _isConfirmLoading 
                      ? null 
                      : () => _selectCurrentLocation(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4B260A),
                    disabledBackgroundColor: const Color(0xFF4B260A).withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 3,
                  ),
                  child: _isConfirmLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Выбрать это место',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _searchLocation(query);
      } else {
        setState(() {
          _isSearching = false;
          _searchResults.clear();
        });
      }
    });
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;

    try {
      setState(() {
        _isSearchLoading = true;
      });

      final locations = await locationFromAddress(query);
      if (mounted) {
        setState(() {
          _isSearching = locations.isNotEmpty;
          _searchResults = locations;
          _isSearchLoading = false;
        });
        
        if (locations.length == 1) {
          await _selectSearchResult(locations.first);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearchLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка поиска места: $e')),
        );
      }
    }
  }

  Future<void> _selectSearchResult(Location location) async {
    final newPosition = LatLng(location.latitude, location.longitude);
    
    setState(() {
      _currentPosition = newPosition;
      _markers.clear();
      _markers.add(
        Marker(
          point: newPosition,
          child: const Icon(
            Icons.location_on,
            color: Color(0xFF4B260A),
            size: 40,
          ),
        ),
      );
      _isSearching = false;
      _searchResults.clear();
    });

    _mapController.move(newPosition, 15);

    try {
      final address = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (address.isNotEmpty && mounted) {
        final place = address.first;
        final fullAddress = '${place.street ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}';
        _searchController.text = fullAddress;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка получения адреса: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() => _isLoading = true);
      
      bool serviceEnabled;
      LocationPermission permission;

      // Проверяем, включены ли службы геолокации
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Службы геолокации отключены. Пожалуйста, включите их в настройках устройства.'),
              duration: Duration(seconds: 4),
            ),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      // Проверяем разрешения на доступ к геолокации
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Доступ к местоположению запрещен. Пожалуйста, разрешите доступ в настройках.'),
                duration: Duration(seconds: 4),
              ),
            );
            setState(() => _isLoading = false);
          }
          return;
        }
      }

      // Если доступ запрещен навсегда, предлагаем инструкции
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Доступ к местоположению запрещен навсегда. Пожалуйста, измените настройки в приложении настройки.'),
              duration: Duration(seconds: 4),
            ),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      // Получаем текущее местоположение
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      
      if (mounted) {
        final newPosition = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentPosition = newPosition;
          _markers.clear();
          _markers.add(
            Marker(
              point: newPosition,
              child: const Icon(
                Icons.location_on,
                color: Color(0xFF4B260A),
                size: 40,
              ),
            ),
          );
          _isLoading = false;
        });
        
        // Перемещаем карту к текущему положению
        _mapController.move(newPosition, 15);
        
        // Пытаемся получить адрес по координатам
        try {
          final address = await placemarkFromCoordinates(
            position.latitude, 
            position.longitude
          );
          
          if (address.isNotEmpty && mounted) {
            final place = address.first;
            final List<String> addressParts = [];
            
            if (place.street != null && place.street!.isNotEmpty) {
              addressParts.add(place.street!);
            }
            
            if (place.locality != null && place.locality!.isNotEmpty) {
              addressParts.add(place.locality!);
            }
            
            final fullAddress = addressParts.isNotEmpty 
                ? addressParts.join(', ')
                : 'Текущее местоположение';
                
            // Обновляем поле поиска
            _searchController.text = fullAddress;
          }
        } catch (e) {
          print('Ошибка получения адреса: $e');
          // Не показываем ошибку пользователю, просто устанавливаем общий текст
          if (mounted) {
            _searchController.text = 'Текущее местоположение';
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка получения местоположения: $e'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _selectCurrentLocation() {
    if (_currentPosition != null) {
      setState(() {
        _isConfirmingLocation = true;
        _isConfirmLoading = true;
      });
      _confirmLocation(_currentPosition!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пожалуйста, выберите место на карте'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _confirmLocation(LatLng position) async {
    try {
      final address = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (address.isNotEmpty && mounted) {
        final place = address.first;
        
        // Создаем более полный и структурированный адрес
        final List<String> addressParts = [];
        
        // Добавляем компоненты адреса, если они не пустые
        if (place.street != null && place.street!.isNotEmpty) {
          addressParts.add(place.street!);
        }
        
        if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty && 
            place.thoroughfare != place.street) {
          addressParts.add(place.thoroughfare!);
        }
        
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addressParts.add(place.subLocality!);
        }
        
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }
        
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          addressParts.add(place.administrativeArea!);
        }
        
        if (place.country != null && place.country!.isNotEmpty) {
          addressParts.add(place.country!);
        }
        
        // Объединяем компоненты адреса через запятую
        final fullAddress = addressParts.isNotEmpty 
            ? addressParts.join(', ')
            : 'Адрес не определен';
        
        widget.onAddressSelected(fullAddress, position);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConfirmLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка получения адреса: $e'),
          ),
        );
      }
    }
  }
} 