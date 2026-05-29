import 'package:flutter/material.dart';

class PaymentSuccessScreen extends StatelessWidget {
  final String? paymentId;
  final String? sessionId;

  const PaymentSuccessScreen({
    super.key,
    this.paymentId,
    this.sessionId,
  });

  @override
  Widget build(BuildContext context) {
    final uri = Uri.base;
    final effectivePaymentId = paymentId ?? uri.queryParameters['payment_id'];
    final effectiveSessionId = sessionId ?? uri.queryParameters['session_id'];
    final shouldShowSession = effectiveSessionId != null &&
        effectiveSessionId.isNotEmpty &&
        !effectiveSessionId.contains('CHECKOUT_SESSION_ID');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pago recibido'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 72),
              const SizedBox(height: 16),
              const Text(
                'Tu pago fue procesado',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Puedes volver a revisar el estado en Mis Emergencias.',
                textAlign: TextAlign.center,
              ),
              if (effectivePaymentId != null && effectivePaymentId.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Pago #$effectivePaymentId', style: const TextStyle(color: Colors.grey)),
              ],
              if (shouldShowSession) ...[
                const SizedBox(height: 6),
                Text(
                  'Sesion: $effectiveSessionId',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(context, '/emergency-list', (route) => false);
                  },
                  icon: const Icon(Icons.list_alt),
                  label: const Text('Volver a Mis Emergencias'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
                  },
                  icon: const Icon(Icons.home),
                  label: const Text('Ir al Inicio'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
