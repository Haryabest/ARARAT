const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.paymentConfirm = functions.https.onRequest(async (req, res) => {
  try {
    // Получаем параметры из URL
    const paymentId = req.query.paymentId;
    const orderId = req.query.orderId;
    const amount = parseFloat(req.query.amount);
    
    if (!paymentId || !orderId || isNaN(amount)) {
      return res.status(400).send(generateHTML({
        success: false,
        error: 'Неверные параметры запроса'
      }));
    }
    
    // Проверяем существование платежа
    const paymentRef = admin.firestore().collection('payments').doc(paymentId);
    const paymentDoc = await paymentRef.get();
    
    if (!paymentDoc.exists) {
      return res.status(404).send(generateHTML({
        success: false,
        error: 'Платеж не найден'
      }));
    }
    
    const paymentData = paymentDoc.data();
    
    // Проверяем соответствие данных
    if (paymentData.orderId !== orderId) {
      return res.status(400).send(generateHTML({
        success: false,
        error: 'Несоответствие ID заказа'
      }));
    }
    
    if (Math.abs(paymentData.amount - amount) > 0.01) {
      return res.status(400).send(generateHTML({
        success: false,
        error: 'Несоответствие суммы платежа'
      }));
    }
    
    // Если платеж уже подтвержден
    if (paymentData.status === 'completed') {
      return res.status(200).send(generateHTML({
        success: true,
        status: 'completed',
        message: 'Платеж уже подтвержден'
      }));
    }
    
    // Отмечаем платеж как отсканированный
    if (!paymentData.isScanned) {
      await paymentRef.update({
        isScanned: true,
        scanTime: admin.firestore.FieldValue.serverTimestamp(),
        status: 'processing',
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // Небольшая пауза для имитации обработки
      await new Promise(resolve => setTimeout(resolve, 2000));
    }
    
    // Обновляем статус платежа
    await paymentRef.update({
      status: 'completed',
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Обновляем статус заказа
    await admin.firestore().collection('orders').doc(orderId).update({
      status: 'оплачен',
      paymentStatus: 'completed',
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    return res.status(200).send(generateHTML({
      success: true,
      status: 'completed',
      message: 'Платеж успешно обработан'
    }));
    
  } catch (error) {
    console.error('Ошибка при обработке платежа:', error);
    return res.status(500).send(generateHTML({
      success: false,
      error: 'Произошла ошибка при обработке платежа'
    }));
  }
});

function generateHTML(data) {
  const status = data.success ? 'Успешно' : 'Ошибка';
  const message = data.message || data.error || '';
  const statusColor = data.success ? 'green' : 'red';
  
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Подтверждение платежа</title>
      <style>
        body {
          font-family: Arial, sans-serif;
          margin: 0;
          padding: 20px;
          background-color: #f5f5f5;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          min-height: 100vh;
          text-align: center;
        }
        .payment-card {
          background-color: white;
          border-radius: 10px;
          box-shadow: 0 4px 8px rgba(0,0,0,0.1);
          padding: 30px;
          max-width: 400px;
          width: 100%;
        }
        .status {
          font-size: 24px;
          margin-bottom: 20px;
          color: ${statusColor};
          font-weight: bold;
        }
        .logo {
          margin-bottom: 20px;
          font-size: 28px;
          font-weight: bold;
          color: #663300;
        }
        .message {
          margin-bottom: 20px;
          color: #555;
        }
        .button {
          background-color: #663300;
          color: white;
          border: none;
          padding: 12px 24px;
          border-radius: 5px;
          cursor: pointer;
          font-size: 16px;
          transition: background-color 0.3s;
        }
        .button:hover {
          background-color: #8B4513;
        }
      </style>
    </head>
    <body>
      <div class="payment-card">
        <div class="logo">АРАРАТ</div>
        <div class="status">${status}</div>
        <div class="message">${message}</div>
        <p>Вы можете закрыть эту страницу и вернуться в приложение.</p>
        <button class="button" onclick="window.close()">Закрыть</button>
      </div>
    </body>
    </html>
  `;
} 