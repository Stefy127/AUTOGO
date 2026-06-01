import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/mobile_notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await context.read<MobileNotificationService>().refresh();
      } catch (e, st) {
        debugPrint('Notifications refresh error: $e\n$st');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<MobileNotificationService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          TextButton(
            onPressed: service.unreadCount == 0
                ? null
                : () => service.markAllAsRead(),
            child: const Text('Marcar todo'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => service.refresh(),
          ),
        ],
      ),
      body: service.notifications.isEmpty
          ? const Center(
              child: Text('No tienes notificaciones'),
            )
          : ListView.separated(
              itemCount: service.notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final n = service.notifications[index];
                final createdAt = DateFormat('dd/MM/yyyy HH:mm').format(n.createdAt.toLocal());

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: n.isRead ? Colors.grey.shade300 : Colors.blue.shade100,
                    child: Icon(
                      n.notificationType == 'offer_received'
                          ? Icons.local_offer
                          : Icons.directions_car,
                      color: n.isRead ? Colors.grey.shade700 : Colors.blue.shade800,
                    ),
                  ),
                  title: Text(
                    n.title,
                    style: TextStyle(
                      fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(n.message),
                      const SizedBox(height: 4),
                      Text(
                        createdAt,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  onTap: () async {
                    if (!n.isRead) {
                      await service.markAsRead(n.id);
                    }
                  },
                );
              },
            ),
    );
  }
}
