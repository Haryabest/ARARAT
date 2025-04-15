import 'package:flutter/material.dart';
import 'package:ararat/widgets/custom_form_field.dart';
import 'package:ararat/screens/map/map_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'package:ararat/services/order_service.dart';
import 'package:ararat/services/address_service.dart';
import 'package:ararat/models/address_model.dart';

// Модель для товара в заказе
class OrderItem {
  final String id;
  final String name;
  final double price;
  final int quantity;
  final String? imageUrl;
  
  OrderItem({
    required this.id, 
    required this.name, 
    required this.price, 
    required this.quantity,
    this.imageUrl,
  });
}

class CheckoutForm extends StatefulWidget {
  final List<OrderItem> orderItems;
  final Function()? onOrderCompleted;
  
  const CheckoutForm({
    super.key, 
    this.orderItems = const [],
    this.onOrderCompleted,
  });

  @override
  State<CheckoutForm> createState() => _CheckoutFormState();
}

class _CheckoutFormState extends State<CheckoutForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  // Контроллеры для полей ввода
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _entranceController = TextEditingController();
  final TextEditingController _intercomController = TextEditingController();
  final TextEditingController _apartmentOfficeController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  
  // Переменные для хранения выбранных значений
  String _selectedDeliveryType = 'standard'; // fast, slow, scheduled
  String _selectedPaymentMethod = 'cash'; // cash, qr - только два способа оплаты
  bool _leaveAtDoor = false;
  String _selectedAddress = '';
  LatLng? _selectedLocation;
  bool _isApartment = true; // true - квартира, false - офис
  
  // Переменные для выбора времени доставки
  TimeOfDay? _selectedDeliveryTime;
  String _deliveryTimeText = 'Выберите удобное время';
  
  // Коэффициенты расчета стоимости доставки
  final Map<String, double> _deliveryFactors = {
    'fast': 1.5,      // Быстрая доставка: +50% к базовой стоимости
    'slow': 1.0,      // Стандартная доставка: базовая стоимость
    'scheduled': 1.2, // Доставка к определенному времени: +20% к базовой стоимости
  };
  
  // Сервис для работы с адресами
  final AddressService _addressService = AddressService();
  
  static const int deliveryTypePickup = 0;
  static const int deliveryTypeDelivery = 1;
  
  // Факторы для расчёта стоимости доставки
  static const double baseFreeDeliveryThreshold = 2000.0; // Бесплатная доставка от 2000 руб
  static const double baseDeliveryCost = 300.0; // Базовая стоимость доставки
  static const double deliveryDistanceFactor = 25.0; // Рублей за километр свыше 5 км
  
  // Переменная для отслеживания процесса загрузки
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadDefaultAddress();
  }
  
  // Загрузка адреса по умолчанию
  Future<void> _loadDefaultAddress() async {
    try {
      setState(() => _isLoading = true);
      
      final defaultAddress = await _addressService.getDefaultAddress();
      
      if (defaultAddress != null && mounted) {
        setState(() {
          // Заполняем поля формы данными из адреса по умолчанию
          _addressController.text = '${defaultAddress.city}, ${defaultAddress.street}, д. ${defaultAddress.house}';
          _entranceController.text = defaultAddress.entrance;
          _intercomController.text = defaultAddress.intercom;
          _apartmentOfficeController.text = defaultAddress.apartment;
          _floorController.text = defaultAddress.floor;
          _isApartment = defaultAddress.type != 'Рабочий';
          
          // Сохраняем также исходные данные для возможного использования при отправке
          _selectedAddress = defaultAddress.fullAddress;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Ошибка при загрузке адреса по умолчанию: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  // Получить стоимость доставки на основе типа и общей суммы заказа
  double getDeliveryCost(double orderTotal) {
    final baseCost = 250.0; // Базовая стоимость доставки
    final factor = _deliveryFactors[_selectedDeliveryType] ?? 1.0;
    
    // Если сумма заказа больше 3000, доставка бесплатная
    if (orderTotal > 3000) {
      return 0.0;
    }
    
    return baseCost * factor;
  }
  
  // Высота формы (90% от высоты экрана)
  double get _formHeight => MediaQuery.of(context).size.height * 0.9;
  
  @override
  void dispose() {
    _addressController.dispose();
    _entranceController.dispose();
    _intercomController.dispose();
    _apartmentOfficeController.dispose();
    _floorController.dispose();
    _phoneController.dispose();
    _commentController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    print('CheckoutForm.build: начало построения');
    print('Количество товаров: ${widget.orderItems.length}');
    
    return Container(
      height: _formHeight,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFA99378),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
      ),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок формы
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Оформление заказа',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              
          // Индикатор свайпа
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          
              // Содержимое формы - используем Expanded вместе с SingleChildScrollView
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Блок доставки
                    _buildSectionTitle('Доставка'),
                    const SizedBox(height: 16),
                    
                    // Выбор типа доставки
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C4425),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          _buildDeliveryTypeSelector(),
                          const SizedBox(height: 16),
                          _buildAddressFields(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Блок контактной информации
                    _buildSectionTitle('Контактная информация'),
                    const SizedBox(height: 16),
                    
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C4425),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Телефон
                          CustomFormField(
                            controller: _phoneController,
                            label: 'Телефон',
                            isRequired: true,
                            keyboardType: TextInputType.phone,
                            isAuthScreen: true,
                            labelColor: Colors.white,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Введите номер телефона';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Оставить у двери
                          _buildLeaveAtDoorSwitch(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Блок комментария
                    _buildSectionTitle('Комментарий к заказу'),
                    const SizedBox(height: 16),
                    
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C4425),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _commentController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Например: позвонить по прибытии',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontFamily: 'Inter',
                            fontSize: 14,
                          ),
                          filled: false,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFF50321B), width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFF50321B), width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFF50321B), width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Inter',
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Блок оплаты
                    _buildSectionTitle('Способ оплаты'),
                    const SizedBox(height: 16),
                    
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C4425),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _buildPaymentMethodSelector(),
                    ),
                    const SizedBox(height: 24),
                    
                        // Добавляем общую сумму заказа с учетом доставки и чаевых
                        _buildTotalAmount(),
                    
                    // Кнопка подтверждения заказа
                        Padding(
                          padding: const EdgeInsets.all(16),
                      child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitOrder,
                        style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF50321B),
                              disabledBackgroundColor: const Color(0xFF50321B).withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading 
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Подтвердить заказ',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Заголовок секции
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }
  
  // Выбор типа доставки
  Widget _buildDeliveryTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        Column(
          children: [
            _buildDeliveryOption(
              'fast',
              'Быстрая доставка',
              '30-60 минут',
              'assets/icons/fast_delivery.png',
            ),
            _buildDivider(),
            _buildDeliveryOption(
              'slow',
              'Стандартная доставка',
              '1-2 часа',
              'assets/icons/standard_delivery.png',
            ),
            _buildDivider(),
            _buildDeliveryOption(
              'scheduled',
              'Доставка к определенному времени',
              _selectedDeliveryTime == null ? 'Выберите удобное время' : 'Время: $_deliveryTimeText',
              'assets/icons/scheduled_delivery.png',
            ),
            // Поле выбора времени для запланированной доставки
            if (_selectedDeliveryType == 'scheduled') 
              _buildTimeSelector(),
          ],
        ),
      ],
    );
  }
  
  // Опция доставки
  Widget _buildDeliveryOption(String value, String title, String subtitle, String iconPath) {
    final isSelected = _selectedDeliveryType == value;
    final factor = _deliveryFactors[value] ?? 1.0;
    String priceFactor = '';
    
    if (factor > 1.0) {
      priceFactor = ' (+${((factor - 1) * 100).toInt()}%)';
    } else if (factor < 1.0) {
      priceFactor = ' (-${((1 - factor) * 100).toInt()}%)';
    }
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedDeliveryType = value;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Иконка (заглушка, так как иконки могут отсутствовать)
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF50321B) : Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.local_shipping,
                  size: 16,
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Текст
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle + priceFactor,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            // Индикатор выбора
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF50321B),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
  
  // Разделитель
  Widget _buildDivider() {
    return Container(
      height: 1,
      color: Colors.white.withOpacity(0.2),
    );
  }
  
  // Поля для адреса
  Widget _buildAddressFields() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Адрес доставки',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Добавляем выбор между картой и сохраненными адресами
          Row(
            children: [
              // Кнопка выбора из сохраненных адресов
              Expanded(
                child: GestureDetector(
                  onTap: _showSavedAddresses,
            child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                      color: const Color(0xFF50321B),
                      borderRadius: BorderRadius.circular(8),
                border: Border.all(
                        color: const Color(0xFF50321B).withOpacity(0.5),
                  width: 1.5,
                ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Сохраненные адреса',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Inter',
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C4425),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.list,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Кнопка выбора адреса на карте
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final selectedLocation = await Navigator.push<LatLng>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MapScreen(
                          onAddressSelected: (address, location) {
                            setState(() {
                              _selectedLocation = location;
                              _addressController.text = address;
                            });
                          },
                        ),
                      ),
                    );
                    
                    if (selectedLocation != null) {
                      setState(() {
                        _selectedLocation = selectedLocation;
                        _addressController.text = 'Адрес выбран на карте';
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF50321B),
                borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF50321B).withOpacity(0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        )
                      ],
              ),
              child: Row(
                children: [
                        Expanded(
                    child: Text(
                            'Выбрать на карте',
                      style: TextStyle(
                              color: Colors.white,
                        fontFamily: 'Inter',
                        fontSize: 14,
                      ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C4425),
                            shape: BoxShape.circle,
                          ),
                    child: Icon(
                            Icons.map,
                      color: Colors.white,
                            size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Поле отображения выбранного адреса
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF50321B).withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Text(
                  'Выбранный адрес:',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontFamily: 'Inter',
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _addressController.text.isEmpty 
                      ? 'Пожалуйста, выберите адрес' 
                      : _addressController.text,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Разделитель для визуального отделения
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.2),
            margin: const EdgeInsets.only(bottom: 16),
          ),
          
          // Инструкция для пользователя
          Container(
            margin: EdgeInsets.only(bottom: 16),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFF50321B).withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withOpacity(0.1), 
                width: 1
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white.withOpacity(0.7), size: 18),
                SizedBox(width: 8),
              Expanded(
                  child: Text(
                    "Заполните информацию для доставки. Поля отмеченные звездочкой (*) обязательны для заполнения.",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontFamily: 'Inter',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Тип помещения: Квартира или Офис
          _buildApartmentOfficeToggle(),
          const SizedBox(height: 20),
          
          // Подъезд
          _buildAddressField(
                  controller: _entranceController,
                  label: 'Подъезд',
            hint: 'Номер подъезда',
            icon: Icons.door_front_door,
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value != null && value.isNotEmpty && !RegExp(r'^[0-9]+$').hasMatch(value)) {
                return 'Только цифры';
              }
              return null;
            },
            isRequired: false,
            helperText: 'Укажите номер подъезда',
          ),
          const SizedBox(height: 16),
          
          // Домофон
          _buildAddressField(
                  controller: _intercomController,
                  label: 'Домофон',
            hint: 'Код домофона',
            icon: Icons.dialpad,
            validator: (value) {
              return null;
            },
            isRequired: false,
            helperText: 'Код или номер для входа',
          ),
          const SizedBox(height: 16),
          
          // Квартира/офис
          _buildAddressField(
            controller: _apartmentOfficeController,
            label: _isApartment ? 'Квартира' : 'Офис',
            hint: _isApartment ? 'Номер квартиры' : 'Номер офиса',
            icon: _isApartment ? Icons.apartment : Icons.business,
            validator: (value) {
              return null;
            },
            isRequired: true,
            helperText: _isApartment ? 'Укажите номер квартиры' : 'Укажите номер офиса',
          ),
          const SizedBox(height: 16),
          
          // Этаж
          _buildAddressField(
            controller: _floorController,
            label: 'Этаж',
            hint: 'Номер этажа',
            icon: Icons.stairs,
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value != null && value.isNotEmpty && !RegExp(r'^[0-9]+$').hasMatch(value)) {
                return 'Только цифры';
              }
              return null;
            },
            isRequired: false,
            helperText: 'На каком этаже находится помещение',
              ),
            ],
          ),
    );
  }
  
  // Улучшенное поле для ввода адресных данных
  Widget _buildAddressField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isRequired = false,
    String? helperText,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Row(
            children: [
            Icon(icon, color: Colors.white.withOpacity(0.8), size: 16),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            if (isRequired) 
              Text(
                ' *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF50321B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF50321B).withOpacity(0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 2,
                offset: Offset(0, 1),
              )
            ],
          ),
                child: CustomFormField(
            hintText: hint,
            controller: controller,
            label: '',  // Пустой label, так как мы показываем его отдельно выше
            keyboardType: keyboardType,
            validator: validator,
            // Не используем maxLength здесь
          ),
        ),
        if (helperText != null) 
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 8),
            child: Text(
              helperText,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontFamily: 'Inter',
                fontSize: 12,
              ),
                ),
              ),
            ],
    );
  }
  
  // Переключатель Квартира/Офис улучшенный
  Widget _buildApartmentOfficeToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.home_work,
              color: Colors.white,
              size: 18,
            ),
            SizedBox(width: 8),
            Text(
              'Тип помещения',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            Text(
              ' *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF50321B),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: Offset(0, 2),
              )
            ],
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildToggleOption(true, 'Квартира'),
              _buildToggleOption(false, 'Офис'),
            ],
          ),
        ),
      ],
    );
  }
  
  // Улучшенная опция переключателя
  Widget _buildToggleOption(bool isApartment, String label) {
    final isSelected = _isApartment == isApartment;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _isApartment = isApartment;
          // Обновляем лейбл поля ввода
          if (_apartmentOfficeController.text.isEmpty) {
            // Сбрасываем текст, только если поле пустое
            _apartmentOfficeController.clear();
          }
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: isSelected 
              ? null 
              : Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isApartment ? Icons.apartment : Icons.business,
              color: isSelected ? const Color(0xFF50321B) : Colors.white.withOpacity(0.8),
              size: 16,
            ),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF50321B) : Colors.white,
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Переключатель "Оставить у двери"
  Widget _buildLeaveAtDoorSwitch() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF50321B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF50321B).withOpacity(0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.door_front_door_outlined,
                color: Colors.white.withOpacity(0.9),
                size: 20,
              ),
              const SizedBox(width: 12),
          const Text(
            'Оставить у двери',
            style: TextStyle(
              fontFamily: 'Inter',
                  fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
            ],
          ),
          Container(
            height: 28,
            width: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Stack(
              children: [
                AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  alignment:
                      _leaveAtDoor ? Alignment.centerRight : Alignment.centerLeft,
                  padding: EdgeInsets.symmetric(horizontal: 2),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _leaveAtDoor ? Colors.white : Colors.white.withOpacity(0.3),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
              setState(() {
                          _leaveAtDoor = !_leaveAtDoor;
              });
            },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Выбор способа оплаты
  Widget _buildPaymentMethodSelector() {
    return Column(
      children: [
        _buildPaymentOption(
          'cash',
          'Наличными курьеру',
          Icons.payments_outlined,
        ),
        _buildDivider(),
        _buildPaymentOption(
          'qr',
          'QR кодом',
          Icons.qr_code,
        ),
      ],
    );
  }
  
  // Опция оплаты
  Widget _buildPaymentOption(String value, String title, IconData icon) {
    final isSelected = _selectedPaymentMethod == value;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = value;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF50321B) : Colors.white.withOpacity(0.7),
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF50321B),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
  
  // Открытие карты для выбора адреса
  Future<void> _openMap() async {
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MapScreen(
            onAddressSelected: (address, location) {
              setState(() {
                _addressController.text = address;
                _selectedLocation = location;
                _selectedAddress = address;
              });
            },
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при открытии карты: $e'),
          ),
        );
      }
    }
  }
  
  // Общая сумма заказа
  Widget _buildTotalAmount() {
    final orderItems = widget.orderItems;
    double subtotal = 0.0;
    
    // Расчет стоимости товаров
    for (var item in orderItems) {
      subtotal += (item.price * item.quantity);
    }
    
    // Расчет стоимости доставки
    final deliveryCost = getDeliveryCost(subtotal);
    
    // Общая сумма с учетом доставки и чаевых
    final total = subtotal + deliveryCost;
    
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
        color: const Color(0xFF50321B),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
          _buildTotalRow('Сумма товаров', '${subtotal.toStringAsFixed(0)} ₽'),
          const SizedBox(height: 8),
          _buildTotalRow(
            'Доставка', 
            deliveryCost > 0 ? '${deliveryCost.toStringAsFixed(0)} ₽' : 'Бесплатно',
            deliveryCost > 0 ? null : Colors.green,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: Colors.white24),
          ),
          _buildTotalRow(
            'Итого', 
            '${total.toStringAsFixed(0)} ₽',
            const Color(0xFFA99378),
            FontWeight.bold,
          ),
        ],
      ),
    );
  }
  
  // Строка в разделе итоговой суммы
  Widget _buildTotalRow(String label, String value, [Color? valueColor, FontWeight fontWeight = FontWeight.normal]) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: Colors.white,
            fontWeight: fontWeight,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: valueColor ?? Colors.white,
            fontWeight: fontWeight,
          ),
        ),
      ],
    );
  }

  // Поле выбора времени доставки
  Widget _buildTimeSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: InkWell(
        onTap: _selectTime,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color(0xFF50321B),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFF50321B).withOpacity(0.2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedDeliveryTime == null 
                    ? 'Выберите время доставки'
                    : 'Доставка в $_deliveryTimeText',
                style: TextStyle(
                  color: _selectedDeliveryTime == null 
                      ? Colors.white.withOpacity(0.7)
                      : Colors.white,
                  fontFamily: 'Inter',
                  fontSize: 14,
                ),
              ),
              const Icon(
                Icons.access_time,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Показать диалоговое окно выбора времени
  Future<void> _selectTime() async {
    final currentTime = TimeOfDay.now();
    
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedDeliveryTime ?? currentTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF50321B),
              onPrimary: Colors.white,
              surface: Color(0xFF6C4425),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFFA99378),
          ),
          child: child!,
        );
      },
    );
    
    if (pickedTime != null && mounted) {
      // Проверяем, не раньше ли выбранное время, чем текущее
      final bool isTimeValid = pickedTime.hour > currentTime.hour || 
                             (pickedTime.hour == currentTime.hour && 
                              pickedTime.minute >= currentTime.minute);
      
      if (!isTimeValid) {
        // Показываем ошибку, если выбрано время раньше текущего
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Невозможно выбрать время раньше текущего'),
            backgroundColor: Color(0xFF6C4425),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      
      setState(() {
        _selectedDeliveryTime = pickedTime;
        
        // Форматируем время в строку
        final hour = pickedTime.hour.toString().padLeft(2, '0');
        final minute = pickedTime.minute.toString().padLeft(2, '0');
        _deliveryTimeText = '$hour:$minute';
      });
    }
  }

  // Метод отправки заказа
  Future<void> _submitOrder() async {
    // Предотвращаем повторное нажатие кнопки во время обработки
    if (_isLoading) return;
    
    // Проверяем все обязательные поля
    bool hasErrors = false;

    // Проверка адреса
    if (_addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Необходимо указать адрес доставки'),
          backgroundColor: Colors.red,
        ),
      );
      hasErrors = true;
    }
    
    // Проверка телефона
    else if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Необходимо указать номер телефона'),
          backgroundColor: Colors.red,
        ),
      );
      hasErrors = true;
    }
    
    // Проверка квартиры/офиса
    else if (_apartmentOfficeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Необходимо указать номер ${_isApartment ? 'квартиры' : 'офиса'}'),
          backgroundColor: Colors.red,
        ),
      );
      hasErrors = true;
    }
    
    // Проверка корзины
    else if (widget.orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ваша корзина пуста. Добавьте товары перед оформлением заказа'),
          backgroundColor: Colors.red,
        ),
      );
      hasErrors = true;
    }
    
    // Если есть ошибки, прекращаем оформление заказа
    if (hasErrors) {
      return;
    }
    
    // Устанавливаем состояние загрузки
    setState(() => _isLoading = true);
    
    // Собираем данные о адресе доставки с учетом всех полей
    final deliveryAddress = {
      'address': _addressController.text,
      'entrance': _entranceController.text,
      'intercom': _intercomController.text,
      'apartmentOffice': _apartmentOfficeController.text,
      'floor': _floorController.text,
      'isApartment': _isApartment,
      'fullAddress': _formatFullAddressForDelivery(),
      'location': _selectedLocation != null 
          ? {'latitude': _selectedLocation!.latitude, 'longitude': _selectedLocation!.longitude} 
          : null,
    };
    
    // Создаем форматированный комментарий для заказа, если он есть
    String? formattedComment;
    if (_commentController.text.isNotEmpty) {
      formattedComment = 'Комментарий к заказу: ${_commentController.text}';
      if (_leaveAtDoor) {
        formattedComment += '\nОставить у двери';
      }
    } else if (_leaveAtDoor) {
      formattedComment = 'Оставить у двери';
    }
    
    // Создаем карту с дополнительными метаданными о заказе
    final Map<String, dynamic> orderMetadata = {
      'deviceInfo': {
        'platform': 'flutter',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      'uiVersion': '1.0.0',
      'clientTimestamp': DateTime.now().toIso8601String(),
    };
    
    try {
      // Инициализируем сервис заказов
      final orderService = OrderService();
      
      // Расчет стоимости товаров
      double subtotal = 0.0;
      for (var item in widget.orderItems) {
        subtotal += (item.price * item.quantity);
      }
      
      // Расчет стоимости доставки
      final deliveryCost = getDeliveryCost(subtotal);
      
      // Создаем заказ в Firebase
      final orderId = await orderService.createOrder(
        items: widget.orderItems,
        subtotal: subtotal,
        deliveryCost: deliveryCost,
        paymentMethod: _selectedPaymentMethod,
        deliveryType: _selectedDeliveryType,
        deliveryAddress: deliveryAddress,
        phoneNumber: _phoneController.text,
        comment: formattedComment,
        leaveAtDoor: _leaveAtDoor,
        metadata: orderMetadata,
      );
      
      // Очищаем корзину после успешного создания заказа
      if (widget.onOrderCompleted != null) {
        widget.onOrderCompleted!();
      }
      
      // Сбрасываем состояние загрузки
      if (mounted) {
        setState(() => _isLoading = false);
      }
      
      // Закрываем форму оформления заказа и возвращаемся на главный экран
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      // Показываем сообщение об успешном оформлении заказа, если контекст еще валиден
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Заказ #${orderId.substring(0, 8)} успешно оформлен!'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Мои заказы',
              textColor: Colors.white,
              onPressed: () {
                // Используем Future.delayed, чтобы дать SnackBar закрыться
                // перед навигацией и предотвратить ошибку с контекстом
                Future.delayed(Duration.zero, () {
                  if (mounted) {
                    // Используем BuildContext с корня навигатора для предотвращения ошибок
                    Navigator.of(context, rootNavigator: true).pushNamed('/profile/orders');
                  }
                });
              },
            ),
          ),
        );
      }
    } catch (e) {
      print('Ошибка при оформлении заказа: $e');
      
      // Сбрасываем состояние загрузки
      if (mounted) {
        setState(() => _isLoading = false);
      }
      
      // Показываем сообщение об ошибке, если контекст еще валиден
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при оформлении заказа: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Метод для форматирования полного адреса с учетом всех заполненных полей
  String _formatFullAddressForDelivery() {
    List<String> addressParts = [_addressController.text];
    
    // Добавляем информацию о квартире/офисе
    if (_apartmentOfficeController.text.isNotEmpty) {
      addressParts.add('${_isApartment ? 'кв.' : 'офис'} ${_apartmentOfficeController.text}');
    }
    
    // Добавляем информацию о подъезде
    if (_entranceController.text.isNotEmpty) {
      addressParts.add('подъезд ${_entranceController.text}');
    }
    
    // Добавляем информацию об этаже
    if (_floorController.text.isNotEmpty) {
      addressParts.add('этаж ${_floorController.text}');
    }
    
    // Добавляем информацию о домофоне
    if (_intercomController.text.isNotEmpty) {
      addressParts.add('домофон ${_intercomController.text}');
    }
    
    return addressParts.join(', ');
  }

  // Добавим метод для выбора из сохраненных адресов
  Future<void> _showSavedAddresses() async {
    setState(() => _isLoading = true);
    
    try {
      final addresses = await _addressService.getAddresses();
      
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      if (addresses.isEmpty) {
        // Вместо просто уведомления, предложим перейти к экрану управления адресами
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFFA99378),
            title: const Text(
              'У вас нет сохраненных адресов',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              'Хотите добавить новый адрес?',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Отмена',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _navigateToAddressManagement();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF50321B),
                ),
                child: const Text(
                  'Добавить',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                  ),
          ),
        ),
      ],
          ),
        );
        return;
      }
      
      // Показываем диалог с выбором адреса
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Color(0xFFA99378),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Column(
            children: [
              // Заголовок
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _navigateToAddressManagement();
                      },
                      child: const Text(
                        'Управление',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Inter',
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Text(
                      'Выберите адрес',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              
              // Список адресов
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: addresses.length,
                  itemBuilder: (context, index) {
                    final address = addresses[index];
                    final bool isDefault = address.isDefault;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: const Color(0xFF6C4425),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isDefault ? Colors.white : Colors.transparent,
                          width: isDefault ? 2 : 0,
                        ),
                      ),
                      child: InkWell(
      onTap: () {
                          // Выбираем этот адрес
        setState(() {
                            _addressController.text = address.fullAddress;
                            _entranceController.text = address.entrance;
                            _intercomController.text = address.intercom;
                            _apartmentOfficeController.text = address.apartment;
                            _floorController.text = address.floor;
                            _isApartment = address.type != 'Рабочий';
                            _selectedAddress = address.fullAddress;
                          });
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(8),
      child: Padding(
                          padding: const EdgeInsets.all(12),
        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Иконка типа адреса
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF50321B),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  address.type == 'Домашний' ? Icons.home 
                                  : address.type == 'Рабочий' ? Icons.business 
                                  : Icons.location_on,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              
                              // Информация об адресе
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                                      address.title.isNotEmpty ? address.title : address.type,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Inter',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      address.fullAddress,
              style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
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
                                          color: Colors.white.withOpacity(0.8),
                                          fontFamily: 'Inter',
                                          fontSize: 14,
                                        ),
                                      ),
                                    if (address.entrance.isNotEmpty || address.floor.isNotEmpty)
                                      Text(
                                        'Подъезд: ${address.entrance}${address.floor.isNotEmpty ? ', Этаж: ${address.floor}' : ''}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontFamily: 'Inter',
                                          fontSize: 14,
                                        ),
                                      ),
                                    if (address.intercom.isNotEmpty)
                                      Text(
                                        'Домофон: ${address.intercom}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontFamily: 'Inter',
                                          fontSize: 14,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (isDefault)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'По умолчанию',
                                    style: TextStyle(
                                      color: Color(0xFF50321B),
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
        ),
      ),
    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при загрузке адресов: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Добавляем метод для навигации к экрану управления адресами
  void _navigateToAddressManagement() {
    Navigator.of(context).pushNamed('/profile/addresses').then((_) {
      // После возвращения с экрана управления адресами, проверяем наличие адреса по умолчанию
      _loadDefaultAddress();
    });
  }
} 