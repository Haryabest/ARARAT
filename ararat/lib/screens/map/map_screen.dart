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
  final MapController _mapController = MapController();
  bool _isLoading = true;
  LatLng? _currentPosition;
  final TextEditingController _searchController = TextEditingController();
  final List<Marker> _markers = [];
  List<Location> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;
  
  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_currentPosition == null)
            const Center(child: Text('Location not available'))
          else
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentPosition!,
                initialZoom: 15,
                onTap: (_, point) {
                  setState(() {
                    _markers.clear();
                    _markers.add(
                      Marker(
                        point: point,
                        child: const Icon(
                          Icons.location_on,
                          color: Color(0xFF4B260A),
                          size: 40,
                        ),
                      ),
                    );
                    _currentPosition = point;
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
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () => _searchLocation(_searchController.text),
                        ),
                      ),
                      onChanged: _onSearchChanged,
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
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_searchResults[index].toString()),
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
            child: ElevatedButton(
              onPressed: () => _selectCurrentLocation(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4B260A),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Выбрать это место',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
      final locations = await locationFromAddress(query);
      if (mounted) {
        setState(() {
          _isSearching = true;
          _searchResults = locations;
        });
      }
    } catch (e) {
      if (mounted) {
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
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoading = false);
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoading = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _markers.add(
          Marker(
            point: _currentPosition!,
            child: const Icon(
              Icons.location_on,
              color: Color(0xFF4B260A),
              size: 40,
            ),
          ),
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка получения местоположения: $e')),
        );
      }
    }
  }

  void _selectCurrentLocation() {
    if (_currentPosition != null) {
      _confirmLocation(_currentPosition!);
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
        final fullAddress = '${place.street ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}';
        widget.onAddressSelected(fullAddress, position);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка получения адреса: $e'),
          ),
        );
      }
    }
  }
} 