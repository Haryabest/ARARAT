import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'address_search_screen.dart';
import '../../../../services/address_service.dart';
import '../../../../models/address_model.dart';

class DeliveryAddressesTab extends StatefulWidget {
  const DeliveryAddressesTab({super.key});

  @override
  State<DeliveryAddressesTab> createState() => _DeliveryAddressesTabState();
}

class _DeliveryAddressesTabState extends State<DeliveryAddressesTab> {
  final List<AddressModel> _addresses = [];
  final MapController _mapController = MapController();
  Position? _currentPosition;
  LatLng? _selectedLocation;
  String _selectedAddress = '';
  bool _isLoading = false;
  final AddressService _addressService = AddressService();
  
  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }
  
  // Загрузка адресов из Firestore
  Future<void> _loadAddresses() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final addresses = await _addressService.getAddresses();
      setState(() {
        _addresses.clear();
        _addresses.addAll(addresses);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при загрузке адресов: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Сохранение нового или обновление существующего адреса
  Future<void> _saveAddress(AddressModel address) async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      if (address.id.isEmpty) {
        // Сохраняем новый адрес
        await _addressService.addAddress(address);
      } else {
        // Обновляем существующий адрес
        await _addressService.updateAddress(address);
      }
      
      // Перезагружаем список адресов
      await _loadAddresses();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Адрес успешно сохранен'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при сохранении адреса: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Удаление адреса
  Future<void> _deleteAddress(String addressId) async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      await _addressService.deleteAddress(addressId);
      
      // Перезагружаем список адресов
      await _loadAddresses();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Адрес успешно удален'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при удалении адреса: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Установка адреса по умолчанию
  Future<void> _setDefaultAddress(String addressId) async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      await _addressService.setDefaultAddress(addressId);
      
      // Перезагружаем список адресов
      await _loadAddresses();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Адрес установлен как основной'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при установке адреса по умолчанию: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
                        Flexible(
                          child: Text(
                            'Выберите адрес на карте',
                            style: const TextStyle(
                              color: Color(0xFF50321B),
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
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
                                prefilled: AddressModel(
                                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                                  type: addressType ?? 'Другой',
                                  title: '',
                                  city: city,
                                  street: street,
                                  house: house,
                                  apartment: '',
                                  entrance: '',
                                  floor: '',
                                  intercom: '',
                                  isDefault: false,
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

  void _showAddressForm({AddressModel? existingAddress, String? addressType, AddressModel? prefilled}) {
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
    final TextEditingController entranceController = TextEditingController(
      text: prefilled?.entrance ?? existingAddress?.entrance ?? '',
    );
    final TextEditingController floorController = TextEditingController(
      text: prefilled?.floor ?? existingAddress?.floor ?? '',
    );
    final TextEditingController intercomController = TextEditingController(
      text: prefilled?.intercom ?? existingAddress?.intercom ?? '',
    );
    
    String type = prefilled?.type ?? existingAddress?.type ?? addressType ?? 'Другой';
    bool isDefault = prefilled?.isDefault ?? existingAddress?.isDefault ?? false;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
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
                    Text(
                      existingAddress != null ? 'Изменить адрес' : 'Новый адрес',
                      style: const TextStyle(
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
                          
                          final newAddress = AddressModel(
                            id: existingAddress?.id ?? '',
                            type: type,
                            title: titleController.text,
                            city: cityController.text,
                            street: streetController.text,
                            house: houseController.text,
                            apartment: apartmentController.text,
                            entrance: entranceController.text,
                            floor: floorController.text,
                            intercom: intercomController.text,
                            isDefault: isDefault,
                          );
                          
                          Navigator.pop(context);
                          _saveAddress(newAddress);
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
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // По умолчанию
                        Row(
                          children: [
                            Checkbox(
                              value: isDefault,
                              onChanged: (value) {
                                setModalState(() {
                                  isDefault = value ?? false;
                                });
                              },
                              activeColor: const Color(0xFF50321B),
                            ),
                            const Text(
                              'Использовать как адрес по умолчанию',
                              style: TextStyle(
                                color: Color(0xFF50321B),
                                fontFamily: 'Inter',
                                fontSize: 14,
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
                        Column(
                          children: [
                            _buildRadioOption(
                              title: 'Домашний',
                              value: 'Домашний',
                              groupValue: type,
                              onChanged: (value) {
                                setModalState(() {
                                  type = value!;
                                });
                              },
                            ),
                            _buildRadioOption(
                              title: 'Рабочий',
                              value: 'Рабочий',
                              groupValue: type,
                              onChanged: (value) {
                                setModalState(() {
                                  type = value!;
                                });
                              },
                            ),
                            _buildRadioOption(
                              title: 'Другой',
                              value: 'Другой',
                              groupValue: type,
                              onChanged: (value) {
                                setModalState(() {
                                  type = value!;
                                });
                              },
                            ),
                          ],
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
                                label: 'Квартира/офис',
                                hintText: '101',
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Дополнительные поля
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: entranceController,
                                label: 'Подъезд',
                                hintText: '1',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: floorController,
                                label: 'Этаж',
                                hintText: '5',
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 12),
                        
                        _buildTextField(
                          controller: intercomController,
                          label: 'Домофон',
                          hintText: 'Код домофона',
                        ),
                        
                        const SizedBox(height: 16),
                        const Text(
                          '* Обязательные поля',
                          style: TextStyle(
                            color: Color(0xFF838383),
                            fontFamily: 'Inter',
                            fontSize: 12,
                          ),
                        ),
                        // Добавляем пространство внизу чтобы избежать BOTTOM OVERFLOW
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
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
  
  Widget _buildSavedAddressCard(AddressModel address) {
    final bool isDefault = address.isDefault;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isDefault ? const Color(0xFF50321B) : Colors.grey.shade300,
          width: isDefault ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Иконка типа адреса
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0E8DD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    address.type == 'Домашний' ? Icons.home 
                    : address.type == 'Рабочий' ? Icons.business 
                    : Icons.location_on,
                    color: const Color(0xFF50321B),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Информация об адресе
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              address.title.isNotEmpty ? address.title : address.type,
                              style: const TextStyle(
                                color: Color(0xFF50321B),
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isDefault)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF50321B),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'По умолчанию',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Inter',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        address.fullAddress,
                        style: const TextStyle(
                          color: Color(0xFF50321B),
                          fontFamily: 'Inter',
                          fontSize: 14,
                        ),
                      ),
                      if (address.apartment.isNotEmpty || 
                          address.entrance.isNotEmpty || 
                          address.floor.isNotEmpty || 
                          address.intercom.isNotEmpty)
                        const SizedBox(height: 4),
                      if (address.apartment.isNotEmpty)
                        Text(
                          '${address.type == "Рабочий" ? "Офис" : "Квартира"}: ${address.apartment}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontFamily: 'Inter',
                            fontSize: 14,
                          ),
                        ),
                      if (address.entrance.isNotEmpty || address.floor.isNotEmpty)
                        Text(
                          'Подъезд: ${address.entrance}${address.floor.isNotEmpty ? ', Этаж: ${address.floor}' : ''}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontFamily: 'Inter',
                            fontSize: 14,
                          ),
                        ),
                      if (address.intercom.isNotEmpty)
                        Text(
                          'Домофон: ${address.intercom}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontFamily: 'Inter',
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE0D5C9)),
            const SizedBox(height: 12),
            
            // Кнопки действий
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!isDefault)
                  TextButton.icon(
                    onPressed: () => _setDefaultAddress(address.id),
                    icon: const Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: Color(0xFF50321B),
                    ),
                    label: const Text(
                      'По умолчанию',
                      style: TextStyle(
                        color: Color(0xFF50321B),
                        fontFamily: 'Inter',
                        fontSize: 14,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  )
                else
                  const SizedBox(width: 120),
                
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        _showAddressForm(existingAddress: address);
                      },
                      icon: const Icon(
                        Icons.edit,
                        color: Color(0xFF50321B),
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: () {
                        // Показываем диалог подтверждения удаления
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Удалить адрес?'),
                            content: const Text('Вы уверены, что хотите удалить этот адрес?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Отмена'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _deleteAddress(address.id);
                                },
                                child: const Text(
                                  'Удалить',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.red,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F2E9),
        elevation: 0,
        title: const Text(
          'Адреса доставки',
          style: TextStyle(
            color: Color(0xFF50321B),
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Color(0xFF50321B),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF50321B)))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Кнопка добавления адреса
                  InkWell(
                    onTap: () => _showMap(),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0E8DD),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFE0D5C9),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.add_location_alt,
                            color: Color(0xFF50321B),
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Добавить новый адрес',
                            style: TextStyle(
                              color: Color(0xFF50321B),
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Заголовок для списка адресов
                  if (_addresses.isNotEmpty)
                    const Text(
                      'Сохраненные адреса',
                      style: TextStyle(
                        color: Color(0xFF50321B),
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  
                  if (_addresses.isNotEmpty)
                    const SizedBox(height: 16),
                  
                  // Список сохраненных адресов
                  if (_addresses.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.location_off,
                              color: Color(0xFFE0D5C9),
                              size: 64,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'У вас пока нет сохраненных адресов',
                              style: TextStyle(
                                color: Color(0xFF50321B),
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Добавьте свой первый адрес доставки',
                              style: TextStyle(
                                color: Color(0xFF838383),
                                fontFamily: 'Inter',
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: _addresses.length,
                        itemBuilder: (context, index) {
                          return _buildSavedAddressCard(_addresses[index]);
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }
} 