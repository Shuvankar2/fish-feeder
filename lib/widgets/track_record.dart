import 'package:flutter/material.dart';
import 'glass_container.dart';

class TrackRecord extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  final String? activeDayOrDate;

  const TrackRecord({
    super.key,
    required this.history,
    this.activeDayOrDate,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Track Record',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (activeDayOrDate != null) ...[
                const SizedBox(height: 4),
                Text(
                  'For: $activeDayOrDate',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF00FF87),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No recent feeds', style: TextStyle(color: Colors.white54)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.length,
              separatorBuilder: (context, index) =>
                  Divider(color: Colors.white.withOpacity(0.1)),
              itemBuilder: (context, index) {
                final item = history[index];
                final isAuto = item['type'] == 'Auto-Fed';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isAuto ? Icons.timer : Icons.water_drop,
                    color: isAuto ? Colors.blueAccent : const Color(0xFF00FF87),
                  ),
                  title: Text(
                    item['type'],
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: Text(
                    item['time'],
                    style: const TextStyle(color: Colors.white70),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
