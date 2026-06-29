import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'glass_container.dart';

class SchedulingPanel extends StatefulWidget {
  final int feedsPerDay;
  final Map<String, String> schedule;
  final bool isAutomatic;
  final ValueChanged<int> onFeedsChanged;
  final Function(String, TimeOfDay) onTimeChanged;
  final ValueChanged<bool> onModeChanged;
  final String? activeDayOrDate;

  const SchedulingPanel({
    super.key,
    required this.feedsPerDay,
    required this.schedule,
    required this.isAutomatic,
    required this.onFeedsChanged,
    required this.onTimeChanged,
    required this.onModeChanged,
    this.activeDayOrDate,
  });

  @override
  State<SchedulingPanel> createState() => _SchedulingPanelState();
}

class _SchedulingPanelState extends State<SchedulingPanel> {
  Future<void> _selectTime(BuildContext context, String key, String currentTime) async {
    final parts = currentTime.split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1].split(' ')[0]),
    );
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00FF87),
              onPrimary: Colors.black,
              surface: Color(0xFF081E16),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      widget.onTimeChanged(key, picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title + Mode Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scheduling',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (widget.activeDayOrDate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'For: ${widget.activeDayOrDate}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: const Color(0xFF00FF87),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
              // Automatic vs Manual Toggle
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withOpacity(0.05),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => widget.onModeChanged(true),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: widget.isAutomatic ? const Color(0xFF00FF87) : Colors.transparent,
                        ),
                        child: Text(
                          'Automatic',
                          style: GoogleFonts.outfit(
                            color: widget.isAutomatic ? Colors.black : Colors.white60,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => widget.onModeChanged(false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: !widget.isAutomatic ? Colors.orangeAccent : Colors.transparent,
                        ),
                        child: Text(
                          'Manual',
                          style: GoogleFonts.outfit(
                            color: !widget.isAutomatic ? Colors.black : Colors.white60,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Content based on mode
          if (!widget.isAutomatic) ...[ 
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pan_tool_alt_rounded, color: Colors.orangeAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Manual feeding mode. Use the feed button above to feed your fish on demand.',
                      style: GoogleFonts.outfit(
                        color: Colors.orangeAccent.withOpacity(0.9),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Feeds per day selector (up to 10)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Feeds per day', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withOpacity(0.04),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: DropdownButton<int>(
                    value: widget.feedsPerDay.clamp(1, 10),
                    dropdownColor: const Color(0xFF081E16),
                    style: GoogleFonts.outfit(color: const Color(0xFF00FF87), fontWeight: FontWeight.bold),
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00FF87), size: 20),
                    items: List.generate(10, (i) => i + 1).map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text('$value'),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) widget.onFeedsChanged(val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Time slots grid
            ...List.generate(widget.feedsPerDay.clamp(1, 10), (index) {
              final key = 'time_${index + 1}';
              final time = widget.schedule[key] ?? '12:00';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF00FF87).withOpacity(0.1),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF00FF87),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Feed ${index + 1}',
                          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => _selectTime(context, key, time),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF00FF87).withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time, color: Color(0xFF00FF87), size: 14),
                            const SizedBox(width: 6),
                            Text(
                              time,
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF00FF87),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
