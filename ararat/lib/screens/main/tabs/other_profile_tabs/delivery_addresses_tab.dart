import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'address_search_screen.dart';

class DeliveryAddressesTab extends StatefulWidget {
  const DeliveryAddressesTab({super.key});

  @override
  State<DeliveryAddressesTab> createState() => _DeliveryAddressesTabState();
}

class _DeliveryAddressesTabState extends State<DeliveryAddressesTab> {
  final List<Address> _addresses = [];
  MapController _mapController = MapController();
  Position? _currentPosition;
  LatLng? _selectedLocation;
  String _selectedAddress = '';
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
  }
  
  Future<void> _determinePosition() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Проверяем разрешения на использование геолокации
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Проверяем, включены ли службы геолокации
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Получаем текущее местоположение
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      setState(() {
        _currentPosition = position;
        _selectedLocation = LatLng(position.latitude, position.longitude);
      });
      
      // Получаем реальный адрес по координатам
      _getAddressFromCoordinates(_selectedLocation!);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _getAddressFromCoordinates(LatLng location) async {
    try {
      
      // Инициализируем значение по умолчанию
      setState(() {
        _isLoading = true;
      });
      
      // Сначала пробуем получить адрес через API OpenStreetMap
      try {
        final String address = await _getAddressFromOpenStreetMap(location);
        
        if (address.isNotEmpty) {
          
          setState(() {
            _selectedAddress = address;
            _isLoading = false;
          });
          return;
        }
      } catch (e) {
        // Продолжаем с локальным геокодированием
      }
      
      try {
        // Получаем список мест по координатам через локальное геокодирование
        final List<Placemark> placemarks = await placemarkFromCoordinates(
          location.latitude,
          location.longitude,
        );
        
        
        if (placemarks.isNotEmpty) {
          // Берем первое место из списка
          final Placemark place = placemarks.first;
          
          // Выводим все доступные данные для отладки
          
          // Формируем адрес из компонентов
          final String formattedAddress = _formatAddress(place);
          
          setState(() {
            _selectedAddress = formattedAddress;
            _isLoading = false;
          });
        } else {
          
          // Используем резервное решение - создаем простой адрес из координат
          final String fallbackAddress = 'Точка на карте (${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)})';
          
          setState(() {
            _selectedAddress = fallbackAddress;
            _isLoading = false;
          });
        }
      } catch (e) {
        
        // Используем резервное решение - создаем простой адрес из координат
        final String fallbackAddress = 'Точка на карте (${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)})';
        
        setState(() {
          _selectedAddress = fallbackAddress;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _selectedAddress = 'Ошибка определения адреса';
        _isLoading = false;
      });
    }
  }
  
  Future<String> _getAddressFromOpenStreetMap(LatLng location) async {
    try {
      // Формируем URL для запроса к API OpenStreetMap Nominatim
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${location.latitude}&lon=${location.longitude}&zoom=18&addressdetails=1&accept-language=ru');
          
      
      // Добавляем заголовок User-Agent для API OSM (обязательно)
      final response = await http.get(url, headers: {
        'User-Agent': 'ARARAT-App/1.0',
      });
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Получаем детали адреса из ответа
        String formattedAddress = '';
        
        if (data.containsKey('address')) {
          final address = data['address'];
          
          List<String> addressParts = [];
          
          // Добавляем город
          if (address.containsKey('city')) {
            addressParts.add(address['city']);
          } else if (address.containsKey('town')) {
            addressParts.add(address['town']);
          } else if (address.containsKey('village')) {
            addressParts.add(address['village']);
          } else if (address.containsKey('county')) {
            addressParts.add(address['county']);
          }
          
          // Добавляем улицу
          if (address.containsKey('road')) {
            addressParts.add(address['road']);
          } else if (address.containsKey('pedestrian')) {
            addressParts.add(address['pedestrian']);
          } else if (address.containsKey('footway')) {
            addressParts.add(address['footway']);
          }
          
          // Добавляем номер дома
          if (address.containsKey('house_number')) {
            addressParts.add('дом ${address['house_number']}');
          }
          
          formattedAddress = addressParts.join(', ');
          
          // Если не удалось получить точный адрес, используем display_name
          if (formattedAddress.isEmpty && data.containsKey('display_name')) {
            formattedAddress = data['display_name'];
          }
        } else if (data.containsKey('display_name')) {
          formattedAddress = data['display_name'];
        }
        
        return formattedAddress;
      } else {
        return '';
      }
    } catch (e) {
      return '';
    }
  }
  
  String _formatAddress(Placemark place) {
    // Получаем компоненты адреса
    final List<String> addressComponents = [];
    
    // Добавляем страну (если доступно и отличается от России)
    if (place.country != null && place.country!.isNotEmpty && place.country != 'Россия') {
      addressComponents.add(place.country!);
    }
    
    // Добавляем населенный пункт (город или деревню)
    if (place.locality != null && place.locality!.isNotEmpty) {
      addressComponents.add(place.locality!);
    } else if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) {
      addressComponents.add(place.subAdministrativeArea!);
    } else if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
      addressComponents.add(place.administrativeArea!);
    }
    
    // Добавляем улицу
    if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) {
      addressComponents.add(place.thoroughfare!);
    } else if (place.street != null && place.street!.isNotEmpty) {
      addressComponents.add(place.street!);
    }
    
    // Добавляем номер дома
    if (place.subThoroughfare != null && place.subThoroughfare!.isNotEmpty) {
      addressComponents.add('дом ${place.subThoroughfare!}');
    }
    
    // Если адрес пуст, используем данные из поля name или другие доступные данные
    if (addressComponents.isEmpty) {
      if (place.name != null && place.name!.isNotEmpty) {
        return place.name!;
      } else if (place.postalCode != null && place.postalCode!.isNotEmpty) {
        return 'Район с индексом ${place.postalCode}';
      } else {
        return 'Неизвестное местоположение';
      }
    }
    
    // Возвращаем форматированный адрес
    return addressComponents.join(', ');
  }

  void _showMap({String? addressType}) {
    // Сбрасываем состояние
    setState(() {
      _selectedLocation = null;
      _selectedAddress = '';
    });
    
    _determinePosition().then((_) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Color(0xFFE0D5C9),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text(
                            'Отмена',
                            style: TextStyle(
                              color: Color(0xFF50321B),
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                        const Text(
                          'Выберите адрес на карте',
                          style: TextStyle(
                            color: Color(0xFF50321B),
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            if (_selectedLocation != null && _selectedAddress.isNotEmpty && 
                                _selectedAddress != 'Ошибка определения адреса') {
                              Navigator.pop(context);
                              
                              // Разбиваем адрес на компоненты
                              List<String> addressParts = _selectedAddress.split(', ');
                              String city = '';
                              String street = '';
                              String house = '';
                              
                              // Обрабатываем координаты, если адрес указан как "Точка на карте"
                              if (_selectedAddress.startsWith('Точка на карте')) {
                                city = 'Точка на карте';
                                // Извлекаем координаты для сохранения в поле street
                                final RegExp coordRegex = RegExp(r'\((.*?)\)');
                                final Match? match = coordRegex.firstMatch(_selectedAddress);
                                if (match != null && match.groupCount >= 1) {
                                  street = match.group(1) ?? '';
                                }
                              } else {
                                city = addressParts.isNotEmpty ? addressParts[0] : '';
                                street = addressParts.length > 1 ? addressParts[1] : '';
                                house = addressParts.length > 2 ? addressParts[2].replaceAll('дом ', '') : '';
                              }
                              
                              _showAddressForm(
                                prefilled: Address(
                                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                                  type: addressType ?? 'Другой',
                                  title: '',
                                  city: city,
                                  street: street,
                                  house: house,
                                  apartment: '',
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Пожалуйста, выберите корректный адрес'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          child: const Text(
                            'Применить',
                            style: TextStyle(
                              color: Color(0xFF50321B),
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Блок с выбранным адресом
                  if (_selectedAddress.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: const Color(0xFFF0E8DD),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Выбранный адрес:',
                            style: TextStyle(
                              color: Color(0xFF50321B),
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedAddress,
                            style: const TextStyle(
                              color: Color(0xFF50321B),
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  Expanded(
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _selectedLocation ?? const LatLng(56.3, 44.0), // Нижний Новгород по умолчанию
                            initialZoom: 15.0,
                            onTap: (tapPosition, latLng) {
                              setModalState(() {
                                _selectedLocation = latLng;
                                _isLoading = true;
                              });
                              
                              // Получаем реальный адрес для выбранной точки
                              _getAddressFromCoordinates(latLng).then((_) {
                                setModalState(() {
                                  // Обновляем состояние модального окна
                                });
                              });
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.ararat',
                            ),
                            if (_selectedLocation != null)
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: _selectedLocation!,
                                    child: const Icon(
                                      Icons.location_pin,
                                      color: Colors.red,
                                      size: 40,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        if (_isLoading)
                          const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF50321B),
                            ),
                          ),
                        // Кнопка поиска адреса
                        Positioned(
                          right: 16,
                          top: 72, // Ниже кнопки определения местоположения
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddressSearchScreen(
                                    onAddressSelected: (LatLng location, String address) {
                                      setModalState(() {
                                        _selectedLocation = location;
                                        _selectedAddress = address;
                                        _mapController.move(location, 15.0);
                                      });
                                    },
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              height: 40,
                              width: 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.search,
                                color: Color(0xFF50321B),
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 16,
                          top: 16,
                          child: GestureDetector(
                            onTap: () {
                              setModalState(() {
                                _isLoading = true;
                              });
                              
                              _determinePosition().then((_) {
                                if (_selectedLocation != null) {
                                  _mapController.move(
                                    _selectedLocation!,
                                    15.0,
                                  );
                                  setModalState(() {
                                    // Обновляем состояние модального окна
                                  });
                                }
                              });
                            },
                            child: Container(
                              height: 40,
                              width: 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.my_location,
                                color: Color(0xFF50321B),
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    });
  }

  void _showAddressForm({Address? existingAddress, String? addressType, Address? prefilled}) {
    final TextEditingController titleController = TextEditingController(
      text: prefilled?.title ?? existingAddress?.title ?? '',
    );
    final TextEditingController cityController = TextEditingController(
      text: prefilled?.city ?? existingAddress?.city ?? '',
    );
    final TextEditingController streetController = TextEditingController(
      text: prefilled?.street ?? existingAddress?.street ?? '',
    );
    final TextEditingController houseController = TextEditingController(
      text: prefilled?.house ?? existingAddress?.house ?? '',
    );
    final TextEditingController apartmentController = TextEditingController(
      text: prefilled?.apartment ?? existingAddress?.apartment ?? '',
    );
    
    String type = prefilled?.type ?? existingAddress?.type ?? addressType ?? 'Другой';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      'Отмена',
                      style: TextStyle(
                        color: Color(0xFF50321B),
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                  const Text(
                    'Новый адрес',
                    style: TextStyle(
                      color: Color(0xFF50321B),
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      // Сохраняем новый адрес
                      if (cityController.text.isNotEmpty && 
                          streetController.text.isNotEmpty && 
                          houseController.text.isNotEmpty) {
                        
                        final newAddress = Address(
                          id: existingAddress?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                          type: type,
                          title: titleController.text,
                          city: cityController.text,
                          street: streetController.text,
                          house: houseController.text,
                          apartment: apartmentController.text,
                        );
                        
                        setState(() {
                          if (existingAddress != null) {
                            // Обновляем существующий адрес
                            final index = _addresses.indexWhere((a) => a.id == existingAddress.id);
                            if (index != -1) {
                              _addresses[index] = newAddress;
                            }
                          } else {
                            // Добавляем новый адрес
                            _addresses.add(newAddress);
                          }
                        });
                        
                        Navigator.pop(context);
                      } else {
                        // Показываем ошибку, если не все поля заполнены
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Заполните все обязательные поля'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Сохранить',
                      style: TextStyle(
                        color: Color(0xFF50321B),
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Поле для названия адреса
              _buildTextField(
                controller: titleController,
                label: 'Название адреса',
                hintText: 'Например: Работа, Дом брата и т.д.',
              ),
              const SizedBox(height: 16),
              
              // Тип адреса
              const Text(
                'Тип адреса',
                style: TextStyle(
                  color: Color(0xFF50321B),
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              
              // Радио-кнопки для типа адреса
              StatefulBuilder(
                builder: (context, setRadioState) {
                  return Column(
                    children: [
                      _buildRadioOption(
                        title: 'Домашний',
                        value: 'Домашний',
                        groupValue: type,
                        onChanged: (value) {
                          setRadioState(() {
                            type = value!;
                          });
                        },
                      ),
                      _buildRadioOption(
                        title: 'Рабочий',
                        value: 'Рабочий',
                        groupValue: type,
                        onChanged: (value) {
                          setRadioState(() {
                            type = value!;
                          });
                        },
                      ),
                      _buildRadioOption(
                        title: 'Другой',
                        value: 'Другой',
                        groupValue: type,
                        onChanged: (value) {
                          setRadioState(() {
                            type = value!;
                          });
                        },
                      ),
                    ],
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
              // Поля для ввода адреса
              _buildTextField(
                controller: cityController,
                label: 'Город *',
                hintText: 'Москва',
              ),
              const SizedBox(height: 12),
              
              _buildTextField(
                controller: streetController,
                label: 'Улица *',
                hintText: 'ул. Пушкина',
              ),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: houseController,
                      label: 'Дом *',
                      hintText: '10',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: apartmentController,
                      label: 'Квартира',
                      hintText: '101',
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              const Text(
                '* Обязательные поля',
                style: TextStyle(
                  color: Color(0xFF838383),
                  fontFamily: 'Inter',
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildRadioOption({
    required String title,
    required String value,
    required String groupValue,
    required Function(String?) onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: const Color(0xFF50321B),
            ),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2F3036),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF50321B),
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              color: Color(0xFFA2A2A2),
              fontFamily: 'Inter',
              fontSize: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFFE0D5C9),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFFE0D5C9),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFF50321B),
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
  
  void _deleteAddress(String id) {
    setState(() {
      _addresses.removeWhere((address) => address.id == id);
    });
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
            child: Icon(Icons.arrow_back_ios, color: Color(0xFF50321B)),
          ),
        ),
        title: const Text(
          'Адреса доставки',
          style: TextStyle(
            color: Color(0xFFFFFFFF),
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () => _showMap(),
            child: const Padding(
              padding: EdgeInsets.all(12.0),
              child: Icon(Icons.add, color: Color(0xFF50321B)),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Всегда показываем кнопки добавления адресов
            const Text(
              'Адреса доставки',
              style: TextStyle(
                color: Color(0xFFFFFFFF),
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _addressButton(
              'Добавить домашний адрес',
              Icons.home,
              () => _showMap(addressType: 'Домашний'),
            ),
            const SizedBox(height: 12),
            _addressButton(
              'Добавить рабочий адрес',
              Icons.work,
              () => _showMap(addressType: 'Рабочий'),
            ),
            const SizedBox(height: 12),
            _addressButton(
              'Добавить другой адрес',
              Icons.location_on,
              () => _showMap(addressType: 'Другой'),
            ),
            
            // Если есть сохраненные адреса, показываем их список
            if (_addresses.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Мои адреса',
                style: TextStyle(
                  color: Color(0xFF50321B),
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: _addresses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final address = _addresses[index];
                    return _savedAddressCard(
                      address: address,
                      onEdit: () => _showAddressForm(existingAddress: address),
                      onDelete: () => _deleteAddress(address.id),
                    );
                  },
                ),
              ),
            ] else ...[
              // Если адресов нет, добавляем расширяющийся контейнер,
              // чтобы кнопки были вверху экрана
              const Expanded(child: SizedBox()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _addressButton(String text, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: const Color(0xFF50321B),
            ),
            const SizedBox(width: 16),
            Text(
              text,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF50321B),
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Color(0xFF838383),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _savedAddressCard({
    required Address address,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    IconData typeIcon;
    switch (address.type) {
      case 'Домашний':
        typeIcon = Icons.home;
        break;
      case 'Рабочий':
        typeIcon = Icons.work;
        break;
      default:
        typeIcon = Icons.location_on;
    }
    
    final String fullAddress = [
      address.city,
      address.street,
      'д. ${address.house}',
      if (address.apartment.isNotEmpty) 'кв. ${address.apartment}',
    ].join(', ');
    
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                typeIcon,
                size: 18,
                color: const Color(0xFF50321B),
              ),
              const SizedBox(width: 8),
              Text(
                address.type,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF50321B),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onEdit,
                child: const Icon(
                  Icons.edit,
                  size: 18,
                  color: Color(0xFF50321B),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(
                  Icons.delete,
                  size: 18,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          if (address.title.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              address.title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF50321B),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            fullAddress,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF2F3036),
            ),
          ),
        ],
      ),
    );
  }
}

class Address {
  final String id;
  final String type;
  final String title;
  final String city;
  final String street;
  final String house;
  final String apartment;

  Address({
    required this.id,
    required this.type,
    this.title = '',
    required this.city,
    required this.street,
    required this.house,
    this.apartment = '',
  });
} 