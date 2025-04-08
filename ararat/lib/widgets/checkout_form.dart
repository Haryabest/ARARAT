import 'package:flutter/material.dart';
import 'package:ararat/widgets/custom_form_field.dart';
import 'package:ararat/screens/map/map_screen.dart';
import 'package:latlong2/latlong.dart';

class CheckoutForm extends StatefulWidget {
  const CheckoutForm({super.key});

  @override
  State<CheckoutForm> createState() => _CheckoutFormState();
}

class _CheckoutFormState extends State<CheckoutForm> {
  // Контроллеры для полей ввода
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _entranceController = TextEditingController();
  final TextEditingController _intercomController = TextEditingController();
  final TextEditingController _apartmentOfficeController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  
  // Переменные для хранения выбранных значений
  String _selectedDeliveryType = 'fast'; // fast, slow, scheduled
  String _selectedPaymentMethod = 'card'; // card, cash, online
  double _tipAmount = 0.0; // 0.0, 100.0, 200.0, 300.0, 500.0
  bool _leaveAtDoor = false;
  String _selectedAddress = '';
  LatLng? _selectedLocation;
  
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
    return Container(
      height: _formHeight,
      decoration: const BoxDecoration(
        color: Color(0xFFA99378),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
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
          
          // Заголовок
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
          
          // Содержимое формы
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
                            borderSide: const BorderSide(color: Color(0xFF2F3036), width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF2F3036), width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF2F3036), width: 1.5),
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
                    
                    // Блок чаевых
                    _buildSectionTitle('Чаевые'),
                    const SizedBox(height: 16),
                    
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C4425),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _buildTipSelector(),
                    ),
                    const SizedBox(height: 32),
                    
                    // Кнопка подтверждения заказа
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          // Логика подтверждения заказа
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Заказ успешно оформлен!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4B260A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
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
              'Выберите удобное время',
              'assets/icons/scheduled_delivery.png',
            ),
          ],
        ),
      ],
    );
  }
  
  // Опция доставки
  Widget _buildDeliveryOption(String value, String title, String subtitle, String iconPath) {
    final isSelected = _selectedDeliveryType == value;
    
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
                color: isSelected ? const Color(0xFF4B260A) : Colors.white.withOpacity(0.2),
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
                    subtitle,
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
                color: Color(0xFF4B260A),
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Кнопка выбора адреса
          InkWell(
            onTap: _openMap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF2F3036),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(
                      _selectedAddress.isEmpty ? 'Выберите адрес' : _selectedAddress,
                      style: TextStyle(
                        color: _selectedAddress.isEmpty ? Colors.white.withOpacity(0.5) : Colors.white,
                        fontFamily: 'Inter',
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Icon(
                      Icons.location_on,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: CustomFormField(
                  controller: _entranceController,
                  label: 'Подъезд',
                  isAuthScreen: true,
                  labelColor: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CustomFormField(
                  controller: _intercomController,
                  label: 'Домофон',
                  isAuthScreen: true,
                  labelColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: CustomFormField(
                  controller: _apartmentOfficeController,
                  label: 'Квартира/офис',
                  isAuthScreen: true,
                  labelColor: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CustomFormField(
                  controller: _floorController,
                  label: 'Этаж',
                  isAuthScreen: true,
                  labelColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Переключатель "Оставить у двери"
  Widget _buildLeaveAtDoorSwitch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF6C4425),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Оставить у двери',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          Switch(
            value: _leaveAtDoor,
            onChanged: (value) {
              setState(() {
                _leaveAtDoor = value;
              });
            },
            activeColor: const Color(0xFF4B260A),
            activeTrackColor: Colors.white.withOpacity(0.3),
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
          'card',
          'Картой онлайн',
          Icons.credit_card,
        ),
        _buildDivider(),
        _buildPaymentOption(
          'cash',
          'Наличными курьеру',
          Icons.payments_outlined,
        ),
        _buildDivider(),
        _buildPaymentOption(
          'online',
          'Электронными средствами',
          Icons.account_balance_wallet_outlined,
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
              color: isSelected ? const Color(0xFF4B260A) : Colors.white.withOpacity(0.7),
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
                color: Color(0xFF4B260A),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
  
  // Выбор суммы чаевых
  Widget _buildTipSelector() {
    final tipOptions = [0.0, 100.0, 200.0, 300.0, 500.0];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF6C4425),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildTipOption(0.0, 'Без чаевых'),
              _buildDivider(),
              ...tipOptions.where((tip) => tip > 0).map((tip) {
                return Column(
                  children: [
                    _buildTipOption(tip, '${tip.toStringAsFixed(0)} ₽'),
                    if (tip < tipOptions.last) _buildDivider(),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
  
  // Опция чаевых
  Widget _buildTipOption(double amount, String label) {
    final isSelected = _tipAmount == amount;
    
    return InkWell(
      onTap: () {
        setState(() {
          _tipAmount = amount;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: Colors.white,
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF4B260A),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

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
} 