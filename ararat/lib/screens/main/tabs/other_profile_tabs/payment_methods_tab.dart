import 'package:flutter/material.dart';

class PaymentMethodsTab extends StatelessWidget {
  const PaymentMethodsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF50321B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Способы оплаты',
          style: TextStyle(
            color: Color(0xFF50321B),
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Доступные способы оплаты',
              style: TextStyle(
                color: Color(0xFF50321B),
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            // QR-код оплата
            _buildPaymentMethodCard(
              title: 'Оплата по QR-коду',
              icon: Icons.qr_code,
              description: 'Отсканируйте QR-код для оплаты заказа через приложение банка.',
            ),
            
            const SizedBox(height: 12),
            
            // Оплата при получении
            _buildPaymentMethodCard(
              title: 'Оплата при получении',
              icon: Icons.money,
              description: 'Оплатите наличными или картой курьеру при доставке заказа.',
            ),
            
            const SizedBox(height: 24),
            
            const Text(
              'Примечание',
              style: TextStyle(
                color: Color(0xFF50321B),
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Выбор способа оплаты производится при оформлении заказа. Все платежи безопасны и защищены.',
              style: TextStyle(
                color: Colors.black54,
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPaymentMethodCard({
    required String title, 
    required IconData icon, 
    required String description
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6C4425).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF6C4425),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF50321B),
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 