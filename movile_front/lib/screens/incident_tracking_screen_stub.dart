import 'package:flutter/material.dart';

import '../models/models.dart';

class IncidentTrackingScreen extends StatelessWidget {
  final Incident incident;

  const IncidentTrackingScreen({super.key, required this.incident});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Seguimiento #${incident.id}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.description,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (incident.workshop != null)
                      Text('Taller: ${incident.workshop!.name}'),
                    if (incident.technician != null)
                      Text('Técnico: ${incident.technician!.name}'),
                    const SizedBox(height: 12),
                    const Text(
                      'El mapa interactivo está disponible en la app móvil. En web puedes revisar el estado y volver a la lista.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (incident.latitude != null && incident.longitude != null)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Volver'),
              ),
          ],
        ),
      ),
    );
  }
}
