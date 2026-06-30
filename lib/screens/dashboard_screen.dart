import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_session.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import '../widgets/feed_button.dart';
import '../widgets/scheduling_panel.dart';
import '../widgets/track_record.dart';
import '../services/device_service.dart';
import '../services/schedule_service.dart';
import '../services/api_service.dart';

class DeviceModel {
  final String id;
  String name;
  final String serialNumber;
  final String macAddress;
  bool isOnline;
  String connectionMode; // 'Local' or 'Cloud'
  int? foodLevelPercent;
  String firmware;
  DateTime lastSeen;
  String localIP;

  DeviceModel({
    required this.id,
    required this.name,
    required this.serialNumber,
    required this.macAddress,
    this.isOnline = true,
    this.connectionMode = 'Cloud',
    this.foodLevelPercent,
    this.firmware = 'v1.0.4',
    required this.lastSeen,
    required this.localIP,
  });
}

class DashboardScreen extends StatefulWidget {
  final String role;
  const DashboardScreen({super.key, this.role = 'user'});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedBottomTab = 0; // 0 = Home, 1 = Settings, 2 = Support
  String _selectedDay = 'Wed'; // Default highlighted day
  DateTime? _selectedOverrideDate;
  final List<String> _weekDays = const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  // Search Bar state variables
  bool _isSearching = false;
  bool _isVoiceSearching = false;
  List<String> recentSearches = [
    'Flakes Food',
    'Automation Time',
    'Low Level Alert',
    'MongoDB Link'
  ];
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  // Devices Ownership & Switching State
  List<DeviceModel> _devices = [];
  DeviceModel? _selectedDevice;

  // Multi-Device Schedules mapping: deviceId -> (dayName -> scheduleMap)
  Map<String, Map<String, Map<String, dynamic>>> _deviceSchedules = {};

  // Multi-Device Date Overrides: deviceId -> (yyyy-MM-dd -> scheduleMap)
  Map<String, Map<String, Map<String, dynamic>>> _deviceDateOverrides = {};

  // Multi-Device History Logs: deviceId -> History List
  Map<String, List<Map<String, dynamic>>> _deviceHistory = {};

  // Device settings states: deviceId -> Settings Map
  Map<String, Map<String, dynamic>> _deviceSettings = {};

  // Vacation mode states: deviceId -> Vacation Map
  Map<String, Map<String, dynamic>> _deviceVacations = {};

  // Controllers (dynamically synced when switching devices)
  final _wifiSsidController = TextEditingController();
  final _mongoUriController = TextEditingController();
  final _deviceNameController = TextEditingController();

  // Settings State of selected device
  String _portionSize = 'Medium';
  double _lowFoodAlertPercent = 20.0;
  bool _isTestingDbConnection = false;

  // Support State
  final _supportSubjectController = TextEditingController();
  final _supportMessageController = TextEditingController();
  bool _isSubmittingTicket = false;

  // Helper to generate a default schedule map with times for up to 10 feeds
  Map<String, String> _defaultSchedule({
    String t1 = '08:00', String t2 = '12:00', String t3 = '18:00',
  }) {
    final defaults = [t1, t2, t3, '09:00', '10:00', '14:00', '16:00', '20:00', '07:00', '22:00'];
    return {for (int i = 0; i < 10; i++) 'time_${i + 1}': defaults[i]};
  }

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
        setState(() {
          _isSearching = true;
        });
      }
    });
    _fetchDevices();
  }

  bool _isLoadingDevices = false;

  Future<void> _fetchDevices() async {
    if (_isLoadingDevices) return;
    setState(() => _isLoadingDevices = true);

    try {
      final res = await DeviceService.listDevices();
      if (res['success'] == true) {
        final List raw = res['devices'] ?? [];
        final List<DeviceModel> loaded = [];

        for (var d in raw) {
          final devId = (d['device_id'] ?? '').toString();
          final isOnline = d['status'] == 'online' || d['status'] == 'provisioned';
          
          loaded.add(DeviceModel(
            id: devId,
            name: d['notes'] ?? 'AquaGlass Feeder',
            serialNumber: d['serial_number'] ?? '',
            macAddress: d['ip_address'] ?? '00:00:00:00:00:00',
            isOnline: isOnline,
            connectionMode: 'Cloud',
            foodLevelPercent: null,
            firmware: d['firmware_version'] ?? 'v1.0.0',
            lastSeen: DateTime.tryParse(d['last_seen'] ?? '') ?? DateTime.now(),
            localIP: d['ip_address'] ?? '192.168.1.55',
          ));

          _deviceDateOverrides[devId] ??= {};
          _deviceSettings[devId] ??= {
            'portionSize': 'Medium',
            'lowFoodAlertPercent': 20.0,
            'wifiSSID': 'AquaGlass_IoT_Home',
            'mongoURI': 'mongodb+srv://admin:aquaglass_cluster@db.net/feeder',
          };
          _deviceVacations[devId] ??= {
            'isVacationMode': false,
            'vacationStartDate': null,
            'vacationEndDate': null,
          };

          await _fetchDeviceSchedulesAndLogs(devId);
        }

        setState(() {
          _devices = loaded;
          if (_devices.isNotEmpty) {
            _selectedDevice = _devices[0];
            _syncSelectedDeviceState();
          } else {
            _selectedDevice = null;
          }
        });
      }
    } catch (e) {
      _showSnackBar('Error loading feeders from database', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoadingDevices = false);
      }
    }
  }

  Future<void> _fetchDeviceSchedulesAndLogs(String devId) async {
    try {
      final schedRes = await ScheduleService.getSchedules(int.parse(devId));
      if (schedRes['success'] == true) {
        final List rawSched = schedRes['schedules'] ?? [];
        final Map<String, Map<String, dynamic>> daysMap = {};
        for (var day in _weekDays) {
          daysMap[day] = {
            'isAutomatic': true,
            'feedsPerDay': 0,
            'schedule': _defaultSchedule(),
          };
        }

        for (var s in rawSched) {
          final List daysList = s['days'] ?? [];
          final timeStr = s['time'] ?? '08:00';
          
          for (var day in daysList) {
            final dayStr = day.toString();
            if (daysMap.containsKey(dayStr)) {
              final int currentCount = daysMap[dayStr]!['feedsPerDay'];
              if (currentCount < 10) {
                daysMap[dayStr]!['feedsPerDay'] = currentCount + 1;
                daysMap[dayStr]!['schedule']['time_${currentCount + 1}'] = timeStr;
              }
            }
          }
        }
        setState(() {
          _deviceSchedules[devId] = daysMap;
        });
      }

      final logsRes = await FeedLogService.getLogs(int.parse(devId));
      if (logsRes['success'] == true) {
        final List rawLogs = logsRes['feedlogs'] ?? [];
        final mappedLogs = rawLogs.map((l) {
          final triggeredAt = DateTime.tryParse(l['triggered_at'] ?? '') ?? DateTime.now();
          final isAuto = l['trigger_type'] == 'schedule';
          final hourStr = triggeredAt.hour.toString().padLeft(2, '0');
          final minStr = triggeredAt.minute.toString().padLeft(2, '0');
          final amPm = triggeredAt.hour >= 12 ? 'PM' : 'AM';
          
          return {
            'id': l['_id'] ?? '',
            'type': isAuto ? 'Auto-Fed' : 'Manual Feed',
            'time': '$hourStr:$minStr $amPm',
          };
        }).toList();

        setState(() {
          _deviceHistory[devId] = mappedLogs;
        });
      }
    } catch (_) {}
  }

  void _syncSelectedDeviceState() {
    if (_selectedDevice == null) return;
    final devId = _selectedDevice!.id;
    final settings = _deviceSettings[devId]!;

    _portionSize = settings['portionSize'] as String;
    _lowFoodAlertPercent = settings['lowFoodAlertPercent'] as double;
    _wifiSsidController.text = settings['wifiSSID'] as String;
    _mongoUriController.text = settings['mongoURI'] as String;
    _deviceNameController.text = _selectedDevice!.name;
  }

  @override
  void dispose() {
    _wifiSsidController.dispose();
    _mongoUriController.dispose();
    _supportSubjectController.dispose();
    _supportMessageController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  bool _isManualFeeding = false;

  Future<void> handleManualFeed() async {
    if (_selectedDevice == null) return;
    if (!_selectedDevice!.isOnline) {
      _showSnackBar('${_selectedDevice!.name} is Offline. Cannot trigger manual feeding ⚠️', isError: true);
      return;
    }

    setState(() {
      _isManualFeeding = true;
    });

    _showSnackBar('Sending manual feed command to ${_selectedDevice!.name} via Cloud...');

    try {
      final res = await DeviceService.triggerFeed(int.parse(_selectedDevice!.id), amountGrams: 5);
      if (res['success'] == true) {
        _showSnackBar('Feeding complete! 🐠🍽️');
        await _fetchDeviceSchedulesAndLogs(_selectedDevice!.id);
      } else {
        _showSnackBar(res['message'] ?? 'Failed to trigger feed', isError: true);
      }
    } catch (_) {
      _showSnackBar('Connection failed', isError: true);
    }

    setState(() {
      _isManualFeeding = false;
    });
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.outfit(fontWeight: FontWeight.w500)),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF00FF87),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
    );
  }

  void _addRecentSearch(String query) {
    if (query.trim().isEmpty) return;
    setState(() {
      recentSearches.remove(query);
      recentSearches.insert(0, query);
      if (recentSearches.length > 5) {
        recentSearches.removeLast();
      }
    });
  }

  void _startMockVoiceSearch() {
    setState(() {
      _isVoiceSearching = true;
    });
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future.delayed(const Duration(seconds: 2), () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
                setState(() {
                  _isVoiceSearching = false;
                  _searchController.text = 'Fish pellets feeding';
                  _isSearching = true;
                  _addRecentSearch('Fish pellets feeding');
                });
                _showSnackBar('Voice Recognized: "Fish pellets feeding" 🎤');
              }
            });
            
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: AlertDialog(
                backgroundColor: const Color(0xFF05120E).withOpacity(0.9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: const Color(0xFF00FF87).withOpacity(0.3)),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF00FF87).withOpacity(0.15),
                      ),
                      child: const Icon(
                        Icons.mic,
                        color: Color(0xFF00FF87),
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Listening...',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try speaking "Fish pellets feeding" or "portion size"',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF05120E), Color(0xFF0E3327)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Greeting Header (Fades and collapses out during search)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _isSearching ? 0.0 : 1.0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: _isSearching ? 0 : 54,
                  margin: EdgeInsets.fromLTRB(20, _isSearching ? 0 : 16, 20, _isSearching ? 0 : 10),
                  child: _isSearching ? const SizedBox() : _buildGreetingHeader(),
                ),
              ),

              // Tab Bodies & Search Layout
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_selectedBottomTab == 0) ...[
                        // Search bar at the top of the Home tab
                        _buildSearchBar(),
                        const SizedBox(height: 20),
                        
                        // Switch content dynamically with a smooth resize transition
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: _isSearching 
                              ? _buildSearchResultsView() 
                              : _buildHomeTab(),
                        ),
                      ],
                      if (_selectedBottomTab == 1) _buildSettingsTab(),
                      if (_selectedBottomTab == 2) _buildSupportTab(),
                      const SizedBox(height: 80), // Spacer for bottom navigation
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      extendBody: true, // Allow layout to flow beneath navigation bar
    );
  }

  // Header Component (Greeting)
  Widget _buildGreetingHeader() {
    final currentUser = UserSession.currentUser;
    final name = currentUser?.name ?? 'Shuvankar Debnath';
    final avatarDisplay = currentUser?.profilePic ?? (name.isNotEmpty ? name[0].toUpperCase() : 'S');
    final isEmojiAvatar = currentUser?.profilePic != null && currentUser!.profilePic!.runes.length <= 2;

    return Row(
      children: [
        GestureDetector(
          onTap: _navigateToProfile,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar
              Hero(
                tag: 'user-avatar',
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF00FF87).withOpacity(0.15),
                  child: currentUser?.profilePic == null
                      ? const Icon(
                          Icons.person,
                          color: Color(0xFF00FF87),
                          size: 20,
                        )
                      : Text(
                          currentUser!.profilePic!,
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Hello 👋',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.55),
                    ),
                  ),
                  Text(
                    name,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: const SizedBox()),

        // Top Device Selector Dropdown
        if (_devices.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<DeviceModel?>(
                value: _selectedDevice,
                dropdownColor: const Color(0xFF05120E),
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00FF87), size: 16),
                items: [
                  ..._devices.map((device) {
                    return DropdownMenuItem<DeviceModel?>(
                      value: device,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.circle,
                            color: device.isOnline ? const Color(0xFF00FF87) : Colors.redAccent,
                            size: 6,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            device.name.split(' - ')[0],
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  DropdownMenuItem<DeviceModel?>(
                    value: null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_link_rounded, color: Color(0xFF00FF87), size: 12),
                        const SizedBox(width: 6),
                        Text(
                          'Pair Feeder',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF00FF87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                onChanged: (DeviceModel? newDevice) {
                  if (newDevice == null) {
                    _showPairingOptions();
                  } else {
                    setState(() {
                      _selectedDevice = newDevice;
                      _syncSelectedDeviceState();
                    });
                    _showSnackBar('Switched to ${newDevice.name} 🔄');
                  }
                },
              ),
            ),
          ),
        const SizedBox(width: 8),

        // Logout Button
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.05),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: IconButton(
            icon: const Icon(Icons.logout_outlined, color: Colors.redAccent, size: 16),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ),
      ],
    );
  }

  // Search Bar Component
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
        onTap: () {
          setState(() {
            _isSearching = true;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search dashboard, controls, settings...',
          hintStyle: GoogleFonts.outfit(color: Colors.white.withOpacity(0.35)),
          prefixIcon: GestureDetector(
            onTap: () {
              if (_isSearching) {
                _searchFocusNode.unfocus();
                _searchController.clear();
                setState(() {
                  _isSearching = false;
                });
              }
            },
            child: Icon(
              _isSearching ? Icons.arrow_back : Icons.search,
              color: const Color(0xFF00FF87),
              size: 20,
            ),
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchController.text.isNotEmpty || _isSearching)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white60, size: 16),
                  onPressed: () {
                    _searchController.clear();
                    _searchFocusNode.unfocus();
                    setState(() {
                      _isSearching = false;
                    });
                  },
                ),
              IconButton(
                icon: Icon(
                  _isVoiceSearching ? Icons.mic : Icons.mic_none,
                  color: _isVoiceSearching ? Colors.redAccent : const Color(0xFF00FF87),
                  size: 20,
                ),
                onPressed: _startMockVoiceSearch,
              ),
              const SizedBox(width: 8),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            _addRecentSearch(value.trim());
          }
        },
      ),
    );
  }

  // Search Results / Recent Searches View
  Widget _buildSearchResultsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Searches',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (recentSearches.isNotEmpty)
              TextButton(
                onPressed: () {
                  setState(() {
                    recentSearches.clear();
                  });
                  _showSnackBar('Recent searches cleared 🗑️');
                },
                child: Text(
                  'Clear All',
                  style: GoogleFonts.outfit(
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (recentSearches.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'No recent searches',
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentSearches.length,
            itemBuilder: (context, index) {
              final item = recentSearches[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const Icon(Icons.history, color: Colors.white30, size: 18),
                title: Text(
                  item,
                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white30, size: 14),
                  onPressed: () {
                    setState(() {
                      recentSearches.removeAt(index);
                    });
                  },
                ),
                onTap: () {
                  setState(() {
                    _searchController.text = item;
                  });
                  _showSnackBar('Searching: "$item" 🔍');
                },
              );
            },
          ),
      ],
    );
  }

  // Helper to get the active schedule data (date override takes priority)
  Map<String, dynamic> _getActiveScheduleData() {
    if (_selectedDevice == null) {
      return {
        'isAutomatic': true,
        'feedsPerDay': 0,
        'schedule': <String, String>{},
      };
    }
    final devId = _selectedDevice!.id;
    final overrides = _deviceDateOverrides[devId] ?? {};
    final schedules = _deviceSchedules[devId] ?? {};

    if (_selectedOverrideDate != null) {
      final key = '${_selectedOverrideDate!.year}-${_selectedOverrideDate!.month.toString().padLeft(2, '0')}-${_selectedOverrideDate!.day.toString().padLeft(2, '0')}';
      if (overrides.containsKey(key)) {
        return overrides[key]!;
      }
    }
    return schedules[_selectedDay] ?? {
      'isAutomatic': true,
      'feedsPerDay': 2,
      'schedule': _defaultSchedule(),
    };
  }

  String _formatOverrideDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // --- HOME TAB CONTENT (Main view) ---
  Widget _buildHomeTab() {
    if (_selectedDevice == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.device_unknown_rounded, color: Colors.white24, size: 64),
            const SizedBox(height: 16),
            Text(
              'No Device Connected',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan a QR code or set up direct WiFi mode to connect your feeder.',
              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showPairingOptions,
              icon: const Icon(Icons.add_link_rounded),
              label: Text('Connect New Feeder', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF87),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ],
        ),
      );
    }

    final devId = _selectedDevice!.id;
    final activeData = _getActiveScheduleData();
    final isAutomatic = activeData['isAutomatic'] as bool;
    final feedsPerDay = activeData['feedsPerDay'] as int;
    final scheduleTimes = Map<String, String>.from(activeData['schedule']);
    
    final overrides = _deviceDateOverrides[devId] ?? {};
    final bool isDateOverrideActive = _selectedOverrideDate != null &&
        overrides.containsKey(
            '${_selectedOverrideDate!.year}-${_selectedOverrideDate!.month.toString().padLeft(2, '0')}-${_selectedOverrideDate!.day.toString().padLeft(2, '0')}');
    final activeDayOrDateText = isDateOverrideActive
        ? _formatOverrideDate(_selectedOverrideDate!)
        : _selectedDay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Device Info + Stats Section
        _buildDeviceInfoSection(),
        const SizedBox(height: 20),

        // Horizontal Calendar day selector
        _buildCalendarSelector(),
        const SizedBox(height: 20),

        // Vacation Mode Card (Separate widget)
        _buildVacationModeSection(),
        const SizedBox(height: 20),

        // Date Override Active Banner
        if (isDateOverrideActive) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF87).withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00FF87).withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_available, color: Color(0xFF00FF87), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Date-specific schedule active for ${_formatOverrideDate(_selectedOverrideDate!)}. This overrides the normal ${_selectedDay} schedule.',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF00FF87),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    final key = '${_selectedOverrideDate!.year}-${_selectedOverrideDate!.month.toString().padLeft(2, '0')}-${_selectedOverrideDate!.day.toString().padLeft(2, '0')}';
                    setState(() {
                      overrides.remove(key);
                      _selectedOverrideDate = null;
                    });
                    _showSnackBar('Date override removed 🗑️');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.06),
                    ),
                    child: const Icon(Icons.close, color: Colors.white54, size: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Manual Override Banner if override is active
        if (!isAutomatic) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Manual feeding mode is ACTIVE${isDateOverrideActive ? ' for ${_formatOverrideDate(_selectedOverrideDate!)}' : ' for $_selectedDay'}. Tap the feed button below to feed manually.',
                    style: GoogleFonts.outfit(
                      color: Colors.orangeAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Feed Button — ONLY shown in Manual mode
          Center(
            child: FeedButton(
              isTriggered: _isManualFeeding,
              onFeedClicked: handleManualFeed,
            ),
          ),
          const SizedBox(height: 32),
        ],

        // Scheduling Panel (binds to selected day or date override)
        SchedulingPanel(
          activeDayOrDate: activeDayOrDateText,
          feedsPerDay: feedsPerDay,
          schedule: scheduleTimes,
          isAutomatic: isAutomatic,
          onFeedsChanged: (val) {
            setState(() {
              if (isDateOverrideActive) {
                final key = '${_selectedOverrideDate!.year}-${_selectedOverrideDate!.month.toString().padLeft(2, '0')}-${_selectedOverrideDate!.day.toString().padLeft(2, '0')}';
                overrides[key]!['feedsPerDay'] = val;
              } else {
                _deviceSchedules[devId]![_selectedDay]!['feedsPerDay'] = val;
              }
            });
          },
          onTimeChanged: (key, time) {
            setState(() {
              final formattedTime =
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
              if (isDateOverrideActive) {
                final dateKey = '${_selectedOverrideDate!.year}-${_selectedOverrideDate!.month.toString().padLeft(2, '0')}-${_selectedOverrideDate!.day.toString().padLeft(2, '0')}';
                overrides[dateKey]!['schedule'][key] = formattedTime;
              } else {
                _deviceSchedules[devId]![_selectedDay]!['schedule'][key] = formattedTime;
              }
            });
          },
          onModeChanged: (val) {
            setState(() {
              if (isDateOverrideActive) {
                final key = '${_selectedOverrideDate!.year}-${_selectedOverrideDate!.month.toString().padLeft(2, '0')}-${_selectedOverrideDate!.day.toString().padLeft(2, '0')}';
                overrides[key]!['isAutomatic'] = val;
              } else {
                _deviceSchedules[devId]![_selectedDay]!['isAutomatic'] = val;
              }
            });
            _showSnackBar(val
                ? 'Automatic Schedule Enabled 📅'
                : 'Manual Feeding Activated ⚠️');
          },
        ),
        const SizedBox(height: 24),

        // History Log
        TrackRecord(
          history: _deviceHistory[devId] ?? [],
          activeDayOrDate: activeDayOrDateText,
        ),
      ],
    );
  }

  // --- DEVICE INFO + STATS SECTION ---
  Widget _buildDeviceInfoSection() {
    if (_selectedDevice == null) return const SizedBox();

    final foodPercent = _selectedDevice!.foodLevelPercent;
    final todayFeedCount = (_deviceHistory[_selectedDevice!.id] ?? []).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Device Connection Row
          _buildConnectedDeviceRow(),
          const SizedBox(height: 16),

          // Divider
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.06),
          ),
          const SizedBox(height: 16),

          // Stats Row: Remaining Food + Today's Feed Count
          Row(
            children: [
              // Remaining Food
              Expanded(
                child: _buildStatCard(
                  icon: Icons.inventory_2_rounded,
                  label: 'Remaining Food',
                  value: foodPercent != null ? '$foodPercent%' : 'NA',
                  valueColor: foodPercent == null 
                      ? Colors.white54
                      : foodPercent <= 20
                          ? Colors.redAccent
                          : foodPercent <= 50
                              ? Colors.orangeAccent
                              : const Color(0xFF00FF87),
                  progressValue: foodPercent != null ? foodPercent / 100.0 : 0.0,
                  progressColor: foodPercent == null
                      ? Colors.white24
                      : foodPercent <= 20
                          ? Colors.redAccent
                          : foodPercent <= 50
                              ? Colors.orangeAccent
                              : const Color(0xFF00FF87),
                ),
              ),
              const SizedBox(width: 12),
              // Today's Feed Count
              Expanded(
                child: _buildStatCard(
                  icon: Icons.restaurant_rounded,
                  label: "Today's Feeds",
                  value: '$todayFeedCount',
                  valueColor: const Color(0xFF00FF87),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedDeviceRow() {
    if (_selectedDevice == null) return const SizedBox();

    return Row(
      children: [
        // Device icon with status indicator
        Stack(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF00FF87).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.developer_board,
                color: Color(0xFF00FF87),
                size: 22,
              ),
            ),
            // Online/Offline dot
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _selectedDevice!.isOnline ? const Color(0xFF00FF87) : Colors.redAccent,
                  border: Border.all(color: const Color(0xFF05120E), width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        // Device info text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedDevice!.name,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (_selectedDevice!.isOnline
                              ? const Color(0xFF00FF87)
                              : Colors.redAccent)
                          .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _selectedDevice!.isOnline ? 'Online' : 'Offline',
                      style: GoogleFonts.outfit(
                        color: _selectedDevice!.isOnline
                            ? const Color(0xFF00FF87)
                            : Colors.redAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Connection mode badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _selectedDevice!.connectionMode == 'Cloud'
                              ? Icons.cloud_outlined
                              : Icons.wifi,
                          color: Colors.white54,
                          size: 11,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _selectedDevice!.connectionMode,
                          style: GoogleFonts.outfit(
                            color: Colors.white54,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Toggle connection mode / more options
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white38, size: 18),
          color: const Color(0xFF081E16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          onSelected: (value) {
            if (value == 'toggle_mode') {
              setState(() {
                _selectedDevice!.connectionMode =
                    _selectedDevice!.connectionMode == 'Cloud' ? 'Local' : 'Cloud';
              });
              _showSnackBar(
                  'Switched to ${_selectedDevice!.connectionMode} connection 🔄');
            } else if (value == 'toggle_status') {
              setState(() {
                _selectedDevice!.isOnline = !_selectedDevice!.isOnline;
              });
              _showSnackBar(_selectedDevice!.isOnline
                  ? 'Device is Online ✅'
                  : 'Device went Offline ⚠️');
            } else if (value == 'disconnect') {
              final devName = _selectedDevice!.name;
              setState(() {
                _devices.removeWhere((d) => d.id == _selectedDevice!.id);
                _selectedDevice = _devices.isNotEmpty ? _devices[0] : null;
                _syncSelectedDeviceState();
              });
              _showSnackBar('Removed device "$devName" 🔌');
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'toggle_mode',
              child: Row(
                children: [
                  Icon(
                    _selectedDevice!.connectionMode == 'Cloud'
                        ? Icons.wifi
                        : Icons.cloud_outlined,
                    color: const Color(0xFF00FF87),
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Switch to ${_selectedDevice!.connectionMode == 'Cloud' ? 'Local' : 'Cloud'}',
                    style: GoogleFonts.outfit(
                        color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'toggle_status',
              child: Row(
                children: [
                  Icon(
                    _selectedDevice!.isOnline
                        ? Icons.power_off
                        : Icons.power,
                    color: Colors.orangeAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _selectedDevice!.isOnline ? 'Simulate Offline' : 'Simulate Online',
                    style: GoogleFonts.outfit(
                        color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'disconnect',
              child: Row(
                children: [
                  const Icon(Icons.link_off, color: Colors.redAccent, size: 16),
                  const SizedBox(width: 10),
                  Text(
                    'Disconnect Device',
                    style: GoogleFonts.outfit(
                        color: Colors.redAccent, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }



  void _showAddDeviceDialog() {
    final deviceNameController = TextEditingController();
    String selectedMode = 'Cloud';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: AlertDialog(
                backgroundColor: const Color(0xFF05120E).withOpacity(0.95),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                      color: const Color(0xFF00FF87).withOpacity(0.2)),
                ),
                title: Row(
                  children: [
                    const Icon(Icons.devices, color: Color(0xFF00FF87), size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Connect Device',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: deviceNameController,
                      style: GoogleFonts.outfit(
                          color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Device Name (e.g. AquaGlass Pro v2)',
                        hintStyle: GoogleFonts.outfit(
                            color: Colors.white30, fontSize: 13),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.15)),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide:
                              BorderSide(color: Color(0xFF00FF87)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Connection Mode',
                      style: GoogleFonts.outfit(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: ['Cloud', 'Local'].map((mode) {
                        final isActive = selectedMode == mode;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setDialogState(() => selectedMode = mode);
                            },
                            child: AnimatedContainer(
                              duration:
                                  const Duration(milliseconds: 200),
                              margin: EdgeInsets.only(
                                  right: mode == 'Cloud' ? 6 : 0,
                                  left: mode == 'Local' ? 6 : 0),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? const Color(0xFF00FF87)
                                        .withOpacity(0.15)
                                    : Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isActive
                                      ? const Color(0xFF00FF87)
                                          .withOpacity(0.4)
                                      : Colors.white.withOpacity(0.08),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    mode == 'Cloud'
                                        ? Icons.cloud_outlined
                                        : Icons.wifi,
                                    color: isActive
                                        ? const Color(0xFF00FF87)
                                        : Colors.white38,
                                    size: 20,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    mode,
                                    style: GoogleFonts.outfit(
                                      color: isActive
                                          ? const Color(0xFF00FF87)
                                          : Colors.white54,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.outfit(color: Colors.white54),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final name = deviceNameController.text.trim();
                      if (name.isEmpty) {
                        _showSnackBar('Please enter a device name',
                            isError: true);
                        return;
                      }
                      setState(() {
                        final newId = 'dev_man_${DateTime.now().millisecondsSinceEpoch}';
                        final newDevice = DeviceModel(
                          id: newId,
                          name: name,
                          serialNumber: 'AG-MAN-${1000 + DateTime.now().second}',
                          macAddress: 'EE:FF:12:34:56:${DateTime.now().second.toString().padLeft(2, '0')}',
                          isOnline: true,
                          connectionMode: selectedMode,
                          foodLevelPercent: null,
                          firmware: 'v1.0.0',
                          lastSeen: DateTime.now(),
                          localIP: selectedMode == 'Local' ? '192.168.4.1' : '192.168.1.150',
                        );
                        _devices.add(newDevice);
                        _deviceSchedules[newId] = {
                          'Sun': {'isAutomatic': true, 'feedsPerDay': 1, 'schedule': _defaultSchedule()},
                          'Mon': {'isAutomatic': true, 'feedsPerDay': 2, 'schedule': _defaultSchedule()},
                          'Tue': {'isAutomatic': true, 'feedsPerDay': 2, 'schedule': _defaultSchedule()},
                          'Wed': {'isAutomatic': true, 'feedsPerDay': 2, 'schedule': _defaultSchedule()},
                          'Thu': {'isAutomatic': true, 'feedsPerDay': 2, 'schedule': _defaultSchedule()},
                          'Fri': {'isAutomatic': true, 'feedsPerDay': 2, 'schedule': _defaultSchedule()},
                          'Sat': {'isAutomatic': false, 'feedsPerDay': 2, 'schedule': _defaultSchedule()},
                        };
                        _deviceDateOverrides[newId] = {};
                        _deviceHistory[newId] = [
                          {"id": 1, "type": "Manual Pair Complete", "time": TimeOfDay.now().format(context)}
                        ];
                        _deviceSettings[newId] = {
                          'portionSize': 'Medium',
                          'lowFoodAlertPercent': 20.0,
                          'wifiSSID': selectedMode == 'Local' ? 'AquaGlass_AP_Direct' : 'Home_WiFi',
                          'mongoURI': 'mongodb+srv://admin:aquaglass_cluster@db.net/feeder',
                        };
                        _selectedDevice = newDevice;
                        _syncSelectedDeviceState();
                      });
                      Navigator.pop(context);
                      _showSnackBar(
                          'Connected to $name via $selectedMode 🔗');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF87),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Connect',
                      style:
                          GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
    double? progressValue,
    Color? progressColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: valueColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: valueColor,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (progressValue != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressValue,
                backgroundColor: Colors.white.withOpacity(0.08),
                valueColor:
                    AlwaysStoppedAnimation<Color>(progressColor ?? valueColor),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalendarSelector() {
    if (_selectedDevice == null) return const SizedBox();
    final devId = _selectedDevice!.id;
    final overrideCount = (_deviceDateOverrides[devId] ?? {}).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row with calendar date picker button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly Planner',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (_selectedOverrideDate != null)
                  Text(
                    'Viewing: ${_formatOverrideDate(_selectedOverrideDate!)}',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: const Color(0xFF00FF87),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            Row(
              children: [
                // Show override count badge
                if (overrideCount > 0)
                  GestureDetector(
                    onTap: () => _showManageOverridesDialog(),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF87).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF00FF87).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$overrideCount override${overrideCount > 1 ? 's' : ''}',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF00FF87),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.settings_outlined, color: Color(0xFF00FF87), size: 10),
                        ],
                      ),
                    ),
                  ),
                // Calendar date picker button
                GestureDetector(
                  onTap: () => _showDateOverridePicker(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _selectedOverrideDate != null
                          ? const Color(0xFF00FF87).withOpacity(0.15)
                          : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _selectedOverrideDate != null
                            ? const Color(0xFF00FF87).withOpacity(0.3)
                            : Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          color: _selectedOverrideDate != null
                              ? const Color(0xFF00FF87)
                              : Colors.white54,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _selectedOverrideDate != null ? 'Change Date' : 'Pick Date',
                          style: GoogleFonts.outfit(
                            color: _selectedOverrideDate != null
                                ? const Color(0xFF00FF87)
                                : Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Clear date override button
                if (_selectedOverrideDate != null) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      setState(() => _selectedOverrideDate = null);
                      _showSnackBar('Switched back to weekly planner view 📅');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: const Icon(Icons.close, color: Colors.white38, size: 14),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Day pills (days only, no dates)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: _weekDays.map((day) {
              final isSelected = _selectedDay == day && _selectedOverrideDate == null;

              return GestureDetector(
                onTap: () {
                  if (_isSearching) {
                    setState(() {
                      _isSearching = false;
                    });
                    _searchFocusNode.unfocus();
                  }
                  setState(() {
                    _selectedDay = day;
                    _selectedOverrideDate = null; // Clear date override when selecting a day
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: isSelected
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF00FF87), Color(0xFF00E676)],
                          )
                        : null,
                    color: isSelected ? null : Colors.white.withOpacity(0.04),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : Colors.white.withOpacity(0.08),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF00FF87).withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : null,
                  ),
                  child: Text(
                    day,
                    style: GoogleFonts.outfit(
                      color: isSelected ? Colors.black : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // --- DATE OVERRIDE PICKER ---
  void _showDateOverridePicker() async {
    if (_selectedDevice == null) return;
    final devId = _selectedDevice!.id;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedOverrideDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00FF87),
              onPrimary: Colors.black,
              surface: Color(0xFF081E16),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF05120E),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF00FF87),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final key = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      // Determine the day name for this date
      const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final dayName = dayNames[picked.weekday - 1];

      final overrides = _deviceDateOverrides[devId] ??= {};
      final schedules = _deviceSchedules[devId] ??= {};

      setState(() {
        _selectedDay = dayName;
        _selectedOverrideDate = picked;

        // Create override from the base day schedule if it doesn't exist
        if (!overrides.containsKey(key)) {
          final baseDayData = schedules[dayName] ?? {
            'isAutomatic': true,
            'feedsPerDay': 2,
            'schedule': _defaultSchedule(),
          };
          overrides[key] = {
            'isAutomatic': baseDayData['isAutomatic'],
            'feedsPerDay': baseDayData['feedsPerDay'],
            'schedule': Map<String, String>.from(baseDayData['schedule']),
          };
          _showSnackBar('Date override created for ${_formatOverrideDate(picked)} (\'$dayName\') 📆');
        } else {
          _showSnackBar('Editing existing override for ${_formatOverrideDate(picked)} ✏️');
        }
      });
    }
  }

  // --- MANAGE OVERRIDES DIALOG ---
  void _showManageOverridesDialog() {
    if (_selectedDevice == null) return;
    final devId = _selectedDevice!.id;
    final overrides = _deviceDateOverrides[devId] ?? {};

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final overrideKeys = overrides.keys.toList()..sort();
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: AlertDialog(
                backgroundColor: const Color(0xFF05120E).withOpacity(0.95),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: const Color(0xFF00FF87).withOpacity(0.2)),
                ),
                title: Row(
                  children: [
                    const Icon(Icons.settings_backup_restore, color: Color(0xFF00FF87), size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Manage Overrides',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                content: overrideKeys.isEmpty
                    ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today_outlined, color: Colors.white24, size: 40),
                            const SizedBox(height: 12),
                            Text(
                              'No overrides scheduled',
                              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : SizedBox(
                        width: double.maxFinite,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: overrideKeys.length,
                          itemBuilder: (context, index) {
                            final key = overrideKeys[index];
                            final overrideData = overrides[key]!;
                            final parts = key.split('-');
                            final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
                            final formattedDate = _formatOverrideDate(date);
                            final feedsCount = overrideData['feedsPerDay'] as int;
                            final isAuto = overrideData['isAutomatic'] as bool;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          formattedDate,
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${isAuto ? "Auto" : "Manual"} • $feedsCount Feed${feedsCount > 1 ? "s" : ""}',
                                          style: GoogleFonts.outfit(
                                            color: isAuto ? const Color(0xFF00FF87) : Colors.orangeAccent,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Edit Button
                                  IconButton(
                                    icon: const Icon(Icons.edit_calendar, color: Color(0xFF00FF87), size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _selectedOverrideDate = date;
                                        // Pick corresponding week day name
                                        const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                                        _selectedDay = dayNames[date.weekday - 1];
                                      });
                                      Navigator.pop(context);
                                      _showSnackBar('Editing override for $formattedDate ✏️');
                                    },
                                  ),
                                  // Cancel (Delete) Button
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        overrides.remove(key);
                                        if (_selectedOverrideDate != null) {
                                          final currentSelectedKey = '${_selectedOverrideDate!.year}-${_selectedOverrideDate!.month.toString().padLeft(2, '0')}-${_selectedOverrideDate!.day.toString().padLeft(2, '0')}';
                                          if (currentSelectedKey == key) {
                                            _selectedOverrideDate = null;
                                          }
                                        }
                                      });
                                      setDialogState(() {});
                                      _showSnackBar('Cancelled override for $formattedDate 🗑️');
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Close',
                      style: GoogleFonts.outfit(color: Colors.white54, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- SEPARATED VACATION MODE SECTION ---
  Widget _buildVacationModeSection() {
    if (_selectedDevice == null) return const SizedBox();
    final devId = _selectedDevice!.id;
    final vac = _deviceVacations[devId] ?? {
      'isVacationMode': false,
      'vacationStartDate': null,
      'vacationEndDate': null,
    };
    final bool isVacMode = vac['isVacationMode'] as bool;
    final DateTime? startDate = vac['vacationStartDate'] as DateTime?;
    final DateTime? endDate = vac['vacationEndDate'] as DateTime?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isVacMode
            ? const Color(0xFF00FF87).withOpacity(0.06)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isVacMode
              ? const Color(0xFF00FF87).withOpacity(0.2)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.flight_takeoff_rounded,
                    color: isVacMode ? const Color(0xFF00FF87) : Colors.white54,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vacation Mode',
                        style: GoogleFonts.outfit(
                          color: isVacMode ? const Color(0xFF00FF87) : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Bypasses scheduling with minimal portions',
                        style: GoogleFonts.outfit(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Switch(
                value: isVacMode,
                activeColor: const Color(0xFF00FF87),
                activeTrackColor: const Color(0xFF00FF87).withOpacity(0.3),
                inactiveThumbColor: Colors.white38,
                inactiveTrackColor: Colors.white.withOpacity(0.1),
                onChanged: (val) {
                  if (val) {
                    _showVacationTypeDialog();
                  } else {
                    setState(() {
                      _deviceVacations[devId]!['isVacationMode'] = false;
                      _deviceVacations[devId]!['vacationStartDate'] = null;
                      _deviceVacations[devId]!['vacationEndDate'] = null;
                    });
                    _showSnackBar('Vacation Mode Disabled 🏡');
                  }
                },
              ),
            ],
          ),
          if (isVacMode && startDate != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF87).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00FF87).withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.date_range, color: Color(0xFF00FF87), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      startDate == endDate
                          ? '${_formatOverrideDate(startDate)} (Single day)'
                          : '${_formatOverrideDate(startDate)} → ${_formatOverrideDate(endDate!)}',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF00FF87),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showVacationTypeDialog(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Change',
                        style: GoogleFonts.outfit(
                          color: Colors.white60,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showVacationTypeDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF05120E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Set Vacation Dates',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose to set vacation for a single day or a date range.',
                style: GoogleFonts.outfit(
                  color: Colors.white54,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              _buildVacationOption(
                icon: Icons.today_rounded,
                title: 'Single Date',
                subtitle: 'Vacation for one specific day',
                onTap: () {
                  Navigator.pop(context);
                  _showSingleDateVacation();
                },
              ),
              const SizedBox(height: 12),
              _buildVacationOption(
                icon: Icons.date_range_rounded,
                title: 'Date Range',
                subtitle: 'Vacation across multiple days',
                onTap: () {
                  Navigator.pop(context);
                  _showVacationDatePicker();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVacationOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF00FF87).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF00FF87), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white30, size: 20),
          ],
        ),
      ),
    );
  }

  void _showSingleDateVacation() async {
    if (_selectedDevice == null) return;
    final devId = _selectedDevice!.id;
    final now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00FF87),
              onPrimary: Colors.black,
              surface: Color(0xFF081E16),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF05120E),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF00FF87),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _deviceVacations[devId]!['isVacationMode'] = true;
        _deviceVacations[devId]!['vacationStartDate'] = picked;
        _deviceVacations[devId]!['vacationEndDate'] = picked;
      });
      _showSnackBar('Vacation Mode active for ${_formatOverrideDate(picked)} ✈️');
    }
  }

  void _showVacationDatePicker() async {
    if (_selectedDevice == null) return;
    final devId = _selectedDevice!.id;
    final now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: now, end: now.add(const Duration(days: 3))),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00FF87),
              onPrimary: Colors.black,
              surface: Color(0xFF081E16),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF05120E),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF00FF87),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _deviceVacations[devId]!['isVacationMode'] = true;
        _deviceVacations[devId]!['vacationStartDate'] = picked.start;
        _deviceVacations[devId]!['vacationEndDate'] = picked.end;
      });
      _showSnackBar('Vacation Mode active from ${_formatOverrideDate(picked.start)} to ${_formatOverrideDate(picked.end)} ✈️');
    }
  }

  // --- SETTINGS TAB ---
  Widget _buildSettingsTab() {
    if (_selectedDevice == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Center(
          child: Text(
            'Connect a device to customize settings',
            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 14),
          ),
        ),
      );
    }

    final devId = _selectedDevice!.id;
    final settings = _deviceSettings[devId]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Device Settings',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),

        // Device Profile & Controls (Rename, Restart, Transfer, Remove)
        _buildSettingsCard(
          title: 'Feeder Device Configuration',
          icon: Icons.settings_input_composite_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Rename input
              TextField(
                controller: _deviceNameController,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Feeder Name',
                  labelStyle: GoogleFonts.outfit(color: Colors.white60),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.save_rounded, color: Color(0xFF00FF87), size: 20),
                    onPressed: () {
                      final newName = _deviceNameController.text.trim();
                      if (newName.isEmpty) {
                        _showSnackBar('Name cannot be empty', isError: true);
                        return;
                      }
                      setState(() {
                        _selectedDevice!.name = newName;
                      });
                      _showSnackBar('Feeder renamed to "$newName" ✏️');
                    },
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00FF87)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Status & Info row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('MAC Address:', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
                  Text(_selectedDevice!.macAddress, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Serial Number:', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
                  Text(_selectedDevice!.serialNumber, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Firmware Version:', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
                  Text(_selectedDevice!.firmware, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 20),

              // Dynamic Option Grid
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Restart Feeder
                  _buildSettingsActionButton(
                    icon: Icons.restart_alt_rounded,
                    label: 'Restart Feeder',
                    color: const Color(0xFF00FF87),
                    onTap: _handleDeviceRestart,
                  ),
                  // Check Firmware Update
                  _buildSettingsActionButton(
                    icon: Icons.system_update_rounded,
                    label: 'Firmware Update',
                    color: const Color(0xFF00FF87),
                    onTap: _handleFirmwareUpdate,
                  ),
                  // Transfer Ownership
                  _buildSettingsActionButton(
                    icon: Icons.swap_horizontal_circle_outlined,
                    label: 'Transfer Owner',
                    color: Colors.orangeAccent,
                    onTap: _handleTransferOwnership,
                  ),
                  // Remove Device
                  _buildSettingsActionButton(
                    icon: Icons.delete_forever_rounded,
                    label: 'Remove Feeder',
                    color: Colors.redAccent,
                    onTap: () {
                      final name = _selectedDevice!.name;
                      setState(() {
                        _devices.removeWhere((d) => d.id == devId);
                        _selectedDevice = _devices.isNotEmpty ? _devices[0] : null;
                        _syncSelectedDeviceState();
                      });
                      _showSnackBar('Removed device "$name" 🔌');
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Low Food Slider Card
        _buildSettingsCard(
          title: 'Low Hopper Level Alert',
          icon: Icons.notifications_active_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Alert threshold',
                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
                  ),
                  Text(
                    '${_lowFoodAlertPercent.toInt()}%',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF00FF87),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _lowFoodAlertPercent,
                min: 5.0,
                max: 50.0,
                activeColor: const Color(0xFF00FF87),
                inactiveColor: Colors.white.withOpacity(0.12),
                onChanged: (val) {
                  setState(() {
                    _lowFoodAlertPercent = val;
                    settings['lowFoodAlertPercent'] = val;
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Portion Selector
        _buildSettingsCard(
          title: 'Feeder Portion Settings',
          icon: Icons.restaurant_menu,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Default portion size',
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
              ),
              DropdownButton<String>(
                value: _portionSize,
                dropdownColor: const Color(0xFF081E16),
                style: GoogleFonts.outfit(color: const Color(0xFF00FF87), fontWeight: FontWeight.bold),
                underline: Container(height: 1, color: const Color(0xFF00FF87)),
                items: ['Small', 'Medium', 'Large'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _portionSize = val;
                      settings['portionSize'] = val;
                    });
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // WiFi Configuration Card
        _buildSettingsCard(
          title: 'WiFi Connection Settings',
          icon: Icons.wifi,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _wifiSsidController,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'SSID / Network Name',
                  labelStyle: GoogleFonts.outfit(color: Colors.white60),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00FF87)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    settings['wifiSSID'] = _wifiSsidController.text;
                  });
                  _showSnackBar('WiFi settings saved for ${_selectedDevice!.name}! 📶');
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: const Color(0xFF00FF87).withOpacity(0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  'Save WiFi Config',
                  style: GoogleFonts.outfit(color: const Color(0xFF00FF87)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // MongoDB config integration
        _buildSettingsCard(
          title: 'MongoDB Cluster config',
          icon: Icons.storage_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _mongoUriController,
                obscureText: true,
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Cluster Connection URI',
                  labelStyle: GoogleFonts.outfit(color: Colors.white60),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00FF87)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isTestingDbConnection
                    ? null
                    : () async {
                        setState(() => _isTestingDbConnection = true);
                        await Future.delayed(const Duration(milliseconds: 1500));
                        setState(() {
                          _isTestingDbConnection = false;
                          settings['mongoURI'] = _mongoUriController.text;
                        });
                        _showSnackBar('MongoDB Cluster connection check: Successful! 🟢');
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF87),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isTestingDbConnection
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                      )
                    : Text(
                        'Test & Save Integration',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- DEVICE ACTION MOCKS ---
  void _handleDeviceRestart() async {
    if (_selectedDevice == null) return;
    _showSnackBar('Sending restart command to ${_selectedDevice!.name}... 🔄');
    
    // Simulate connection delay
    await Future.delayed(const Duration(seconds: 2));
    _showSnackBar('${_selectedDevice!.name} successfully rebooted and online! 🟢');
  }

  void _handleFirmwareUpdate() async {
    if (_selectedDevice == null) return;
    
    _showSnackBar('Checking for OTA firmware updates... 📡');
    await Future.delayed(const Duration(seconds: 2));

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool isUpgrading = false;
            double progress = 0.0;

            void startUpgrade() async {
              setDialogState(() => isUpgrading = true);
              for (int i = 0; i <= 10; i++) {
                await Future.delayed(const Duration(milliseconds: 250));
                setDialogState(() {
                  progress = i / 10.0;
                });
              }
              Navigator.pop(context);
              setState(() {
                _selectedDevice!.firmware = 'v1.0.9';
              });
              _showSnackBar('Firmware updated successfully to v1.0.9! 🚀');
            }

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: AlertDialog(
                backgroundColor: const Color(0xFF05120E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: const Color(0xFF00FF87).withOpacity(0.2)),
                ),
                title: Text(
                  'Firmware Update',
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                content: isUpgrading
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Downloading and flashing firmware...',
                            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white.withOpacity(0.08),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00FF87)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(progress * 100).toInt()}% complete',
                            style: GoogleFonts.outfit(color: const Color(0xFF00FF87), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New update available! (v1.0.9)',
                            style: GoogleFonts.outfit(color: const Color(0xFF00FF87), fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This update improves MQTT stability and reduces offline log synchronization latency.',
                            style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                actions: isUpgrading
                    ? []
                    : [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white54)),
                        ),
                        ElevatedButton(
                          onPressed: startUpgrade,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00FF87),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Update Now', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                        ),
                      ],
              ),
            );
          },
        );
      },
    );
  }

  void _handleTransferOwnership() {
    if (_selectedDevice == null) return;
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: const Color(0xFF05120E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: const Color(0xFF00FF87).withOpacity(0.2)),
            ),
            title: Text(
              'Transfer Ownership',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Enter the email address of the new owner. Once transferred, you will lose access to this feeder.',
                  style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Recipient Email',
                    labelStyle: GoogleFonts.outfit(color: Colors.white60),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF00FF87)),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: () {
                  final email = emailController.text.trim();
                  if (email.isEmpty) {
                    _showSnackBar('Please enter a valid email', isError: true);
                    return;
                  }
                  final devName = _selectedDevice!.name;
                  setState(() {
                    _devices.removeWhere((d) => d.id == _selectedDevice!.id);
                    _selectedDevice = _devices.isNotEmpty ? _devices[0] : null;
                    _syncSelectedDeviceState();
                  });
                  Navigator.pop(context);
                  _showSnackBar('Transferred ownership of "$devName" to $email ✉️');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Transfer', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- PAIRING MODAL FLOW ---
  void _showPairingOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF05120E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Pair New Feeder',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose your preferred method to link a new AquaGlass device.',
                style: GoogleFonts.outfit(
                  color: Colors.white54,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              
              // Option 1: QR Code Scanner (Recommended)
              _buildPairingOptionItem(
                icon: Icons.qr_code_scanner_rounded,
                title: 'Scan QR Code (Recommended)',
                subtitle: 'Scan the QR code on the back of the device',
                onTap: () {
                  Navigator.pop(context);
                  _showClaimDeviceDialog();
                },
              ),
              const SizedBox(height: 12),
              
              // Option 2: Wi-Fi Access Point Mode
              _buildPairingOptionItem(
                icon: Icons.wifi_find_rounded,
                title: 'Wi-Fi AP Setup Mode',
                subtitle: 'Connect directly to feeder\'s hotspot',
                onTap: () {
                  Navigator.pop(context);
                  _showClaimDeviceDialog();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPairingOptionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF00FF87).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF00FF87), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white30, size: 20),
          ],
        ),
      ),
    );
  }

  void _simulateQRScanPairing() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future.delayed(const Duration(seconds: 3), () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
                final newId = 'dev_paired_${DateTime.now().millisecondsSinceEpoch}';
                final newDevice = DeviceModel(
                  id: newId,
                  name: 'AquaGlass Nano - Living Room',
                  serialNumber: 'AG-NANO-${1000 + DateTime.now().second * 7}',
                  macAddress: 'F0:08:D1:5A:${DateTime.now().second.toString().padLeft(2, '0')}:E3',
                  lastSeen: DateTime.now(),
                  localIP: '192.168.1.188',
                  foodLevelPercent: null,
                  connectionMode: 'Cloud',
                );

                setState(() {
                  _devices.add(newDevice);
                  _deviceSchedules[newId] = {
                    'Sun': {'isAutomatic': true, 'feedsPerDay': 1, 'schedule': _defaultSchedule()},
                    'Mon': {'isAutomatic': true, 'feedsPerDay': 2, 'schedule': _defaultSchedule()},
                    'Tue': {'isAutomatic': true, 'feedsPerDay': 2, 'schedule': _defaultSchedule()},
                    'Wed': {'isAutomatic': true, 'feedsPerDay': 2, 'schedule': _defaultSchedule()},
                    'Thu': {'isAutomatic': true, 'feedsPerDay': 2, 'schedule': _defaultSchedule()},
                    'Fri': {'isAutomatic': true, 'feedsPerDay': 2, 'schedule': _defaultSchedule()},
                    'Sat': {'isAutomatic': false, 'feedsPerDay': 2, 'schedule': _defaultSchedule()},
                  };
                  _deviceDateOverrides[newId] = {};
                  _deviceHistory[newId] = [
                    {"id": 1, "type": "Setup Complete", "time": TimeOfDay.now().format(context)}
                  ];
                  _deviceSettings[newId] = {
                    'portionSize': 'Medium',
                    'lowFoodAlertPercent': 20.0,
                    'wifiSSID': 'AquaGlass_IoT_Home',
                    'mongoURI': 'mongodb+srv://admin:aquaglass_cluster@db.net/feeder',
                  };
                  _selectedDevice = newDevice;
                  _syncSelectedDeviceState();
                });
                _showSnackBar('New feeder "${newDevice.name}" paired successfully! 🐠🎉');
              }
            });

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: AlertDialog(
                backgroundColor: const Color(0xFF05120E).withOpacity(0.95),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: const Color(0xFF00FF87).withOpacity(0.2)),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    // Animated scanning box
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF00FF87), width: 2),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Icon(Icons.qr_code_2, color: Colors.white.withOpacity(0.3), size: 100),
                          ),
                          // Simulated scanning red line animation
                          AnimatedContainer(
                            duration: const Duration(seconds: 1),
                            child: Align(
                              alignment: Alignment.center,
                              child: Container(
                                height: 2,
                                color: const Color(0xFF00FF87),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Position QR Code in Box',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Align with the QR code printed on the bottom/back of your AquaGlass Feeder',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAPSetupDialog() {
    final ssidController = TextEditingController(text: 'AquaGlass_AP_FE31');
    final passController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool isConnecting = false;

            void connectToAP() async {
              setDialogState(() => isConnecting = true);
              await Future.delayed(const Duration(seconds: 3));
              
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
                final newId = 'dev_paired_${DateTime.now().millisecondsSinceEpoch}';
                final newDevice = DeviceModel(
                  id: newId,
                  name: 'AquaGlass Pro - Office aquarium',
                  serialNumber: 'AG-PRO-${2000 + DateTime.now().second}',
                  macAddress: 'CC:50:E3:42:${DateTime.now().second.toString().padLeft(2, '0')}:9A',
                  lastSeen: DateTime.now(),
                  localIP: '192.168.4.1',
                  foodLevelPercent: null,
                  connectionMode: 'Local',
                );

                setState(() {
                  _devices.add(newDevice);
                  _deviceSchedules[newId] = {
                    'Sun': {'isAutomatic': true, 'feedsPerDay': 1, 'schedule': _defaultSchedule()},
                    'Mon': {'isAutomatic': true, 'feedsPerDay': 2, 'schedule': _defaultSchedule()},
                    'Tue': {'isAutomatic': true, 'feedsPerDay': 2, 'schedule': _defaultSchedule()},
                    'Wed': {'isAutomatic': true, 'feedsPerDay': 2, 'schedule': _defaultSchedule()},
                    'Thu': {'isAutomatic': true, 'feedsPerDay': 2, 'schedule': _defaultSchedule()},
                    'Fri': {'isAutomatic': true, 'feedsPerDay': 2, 'schedule': _defaultSchedule()},
                    'Sat': {'isAutomatic': false, 'feedsPerDay': 2, 'schedule': _defaultSchedule()},
                  };
                  _deviceDateOverrides[newId] = {};
                  _deviceHistory[newId] = [
                    {"id": 1, "type": "AP Configuration Complete", "time": TimeOfDay.now().format(context)}
                  ];
                  _deviceSettings[newId] = {
                    'portionSize': 'Medium',
                    'lowFoodAlertPercent': 20.0,
                    'wifiSSID': ssidController.text,
                    'mongoURI': 'mongodb+srv://admin:aquaglass_cluster@db.net/feeder',
                  };
                  _selectedDevice = newDevice;
                  _syncSelectedDeviceState();
                });
                _showSnackBar('Configured and paired "${newDevice.name}" via Wi-Fi AP Mode! 📶🎉');
              }
            }

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: AlertDialog(
                backgroundColor: const Color(0xFF05120E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: const Color(0xFF00FF87).withOpacity(0.2)),
                ),
                title: Text(
                  'Wi-Fi AP Setup',
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                content: isConnecting
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 16),
                          const CircularProgressIndicator(color: Color(0xFF00FF87)),
                          const SizedBox(height: 24),
                          Text(
                            'Provisioning Wi-Fi credentials to ESP32...',
                            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Device is registering with backend MQTT broker...',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Connect to the hotspot broadcasted by the feeder (e.g. AquaGlass_AP_XXXX), then provision home Wi-Fi details.',
                            style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: ssidController,
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Home Wi-Fi SSID',
                              labelStyle: GoogleFonts.outfit(color: Colors.white60),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                              ),
                              focusedBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFF00FF87)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: passController,
                            obscureText: true,
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Home Wi-Fi Password',
                              labelStyle: GoogleFonts.outfit(color: Colors.white60),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                              ),
                              focusedBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFF00FF87)),
                              ),
                            ),
                          ),
                        ],
                      ),
                actions: isConnecting
                    ? []
                    : [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white54)),
                        ),
                        ElevatedButton(
                          onPressed: connectToAP,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00FF87),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Provision & Connect', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                        ),
                      ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettingsCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF00FF87), size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // --- SUPPORT TAB ---
  Widget _buildSupportTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Customer Support',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),

        // Team info card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF00FF87).withOpacity(0.12), const Color(0xFF00E676).withOpacity(0.03)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF00FF87).withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'DEVELOPED BY',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Shuvankar Debnath',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF00FF87),
                  shadows: [
                    BoxShadow(
                      color: const Color(0xFF00FF87).withOpacity(0.2),
                      blurRadius: 10,
                    )
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'IoT Systems & MongoDB Integration Lab © 2026',
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // FAQs Section
        Text(
          'Frequently Asked Questions',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        _buildFaqTile(
          question: 'How to setup the automatic schedules?',
          answer:
              'Select any day of the week from the Weekly Planner row, enable "Automatic" mode, and set the times and number of feeds. The settings are saved in local state (ready for database sync).',
        ),
        _buildFaqTile(
          question: 'What is the "Override" mode?',
          answer:
              'Override (Manual Override) disables all automatic scheduled feeds for that specific day. This gives you manual control, letting you feed your fish using the FEED NOW button instead of automated time triggers.',
        ),
        _buildFaqTile(
          question: 'How low food hopper alerts work?',
          answer:
              'A sensor inside the physical hopper checks low food levels. You can adjust the warning threshold in the Settings tab (e.g. notify at 20%). Alerts show up as alerts in notifications.',
        ),
        const SizedBox(height: 24),

        // Support Ticket Card
        _buildSettingsCard(
          title: 'Open Support Ticket',
          icon: Icons.contact_support_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _supportSubjectController,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Subject',
                  labelStyle: GoogleFonts.outfit(color: Colors.white60),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00FF87)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _supportMessageController,
                maxLines: 3,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Message Body',
                  labelStyle: GoogleFonts.outfit(color: Colors.white60),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00FF87)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isSubmittingTicket
                    ? null
                    : () async {
                        if (_supportSubjectController.text.isEmpty ||
                            _supportMessageController.text.isEmpty) {
                          _showSnackBar('Please fill in all fields', isError: true);
                          return;
                        }
                        setState(() => _isSubmittingTicket = true);
                        await Future.delayed(const Duration(milliseconds: 1200));
                        setState(() {
                          _isSubmittingTicket = false;
                          _supportSubjectController.clear();
                          _supportMessageController.clear();
                        });
                        _showSnackBar('Ticket submitted! Support will contact you shortly. ✉️');
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF87),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSubmittingTicket
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                      )
                    : Text(
                        'Submit Inquiry',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFaqTile({required String question, required String answer}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        iconColor: const Color(0xFF00FF87),
        collapsedIconColor: Colors.white54,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: GoogleFonts.outfit(fontSize: 13, color: Colors.white70, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // Custom Glass Bottom Navigation Bar
  Widget _buildBottomNavigationBar() {
    return Container(
      height: 68,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF05120E).withOpacity(0.85),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(0, Icons.home_filled, 'Home'),
              _buildNavItem(1, Icons.settings_rounded, 'Settings'),
              _buildNavItem(2, Icons.support_agent_rounded, 'Support'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedBottomTab == index;
    return GestureDetector(
      onTap: () {
        if (_isSearching) {
          setState(() {
            _isSearching = false;
          });
          _searchFocusNode.unfocus();
        }
        setState(() => _selectedBottomTab = index);
      },
      child: Container(
        color: Colors.transparent, // Expand click area
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00FF87).withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF00FF87) : Colors.white60,
                size: 20,
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF00FF87),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const ProfileScreen(),
        transitionsBuilder: (_, anim, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    ).then((_) {
      setState(() {});
    });
  }

  void _showAccountSettingsDialog() {
    final currentUser = UserSession.currentUser;
    if (currentUser == null) {
      _showSnackBar('No user session active.', isError: true);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final currentPassController = TextEditingController();
        final newPassController = TextEditingController();
        final confirmPassController = TextEditingController();

        bool isChangingPassword = false;
        bool isLinking = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final linked = currentUser.linkedMethods;

            void handleLink(String method) async {
              setDialogState(() => isLinking = true);
              await Future.delayed(const Duration(milliseconds: 800));
              setState(() {
                UserSession.linkMethod(currentUser.email, method);
              });
              setDialogState(() {
                isLinking = false;
              });
              _showSnackBar('$method linked to your account successfully! 🔗');
            }

            void handleUnlink(String method) async {
              if (linked.length <= 1) {
                _showSnackBar('Cannot unlink. You must keep at least one login method.', isError: true);
                return;
              }
              setDialogState(() => isLinking = true);
              await Future.delayed(const Duration(milliseconds: 800));
              setState(() {
                UserSession.unlinkMethod(currentUser.email, method);
              });
              setDialogState(() {
                isLinking = false;
              });
              _showSnackBar('$method unlinked from your account successfully! 🔓');
            }

            void handleChangePassword() async {
              final curr = currentPassController.text;
              final newP = newPassController.text;
              final conf = confirmPassController.text;

              if (curr.isEmpty || newP.isEmpty || conf.isEmpty) {
                _showSnackBar('Please fill in all password fields', isError: true);
                return;
              }

              if (curr != currentUser.password) {
                _showSnackBar('Incorrect current password', isError: true);
                return;
              }

              if (newP.length < 6) {
                _showSnackBar('Password must be at least 6 characters', isError: true);
                return;
              }

              if (newP != conf) {
                _showSnackBar('New passwords do not match', isError: true);
                return;
              }

              setDialogState(() => isChangingPassword = true);
              await Future.delayed(const Duration(milliseconds: 1000));

              setState(() {
                UserSession.updatePassword(currentUser.email, newP);
              });

              setDialogState(() {
                isChangingPassword = false;
                currentPassController.clear();
                newPassController.clear();
                confirmPassController.clear();
              });
              _showSnackBar('Password updated successfully! 🔒');
            }

            Widget buildMethodRow(String method, IconData icon, Color color) {
              final isLinked = linked.contains(method);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Icon(icon, color: isLinked ? color : Colors.white24, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            method,
                            style: GoogleFonts.outfit(
                              color: isLinked ? Colors.white : Colors.white38,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            isLinked ? 'Linked' : 'Not Linked',
                            style: GoogleFonts.outfit(
                              color: isLinked ? const Color(0xFF00FF87) : Colors.white24,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isLinked)
                      ElevatedButton(
                        onPressed: linked.length > 1 ? () => handleUnlink(method) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.withOpacity(0.12),
                          foregroundColor: Colors.redAccent,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Colors.redAccent),
                          ),
                        ),
                        child: Text('Unlink', style: GoogleFonts.outfit(fontSize: 12)),
                      )
                    else
                      ElevatedButton(
                        onPressed: () => handleLink(method),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00FF87).withOpacity(0.12),
                          foregroundColor: const Color(0xFF00FF87),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Color(0xFF00FF87)),
                          ),
                        ),
                        child: Text('Link', style: GoogleFonts.outfit(fontSize: 12)),
                      ),
                  ],
                ),
              );
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF0A221A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: const Color(0xFF00FF87).withOpacity(0.2)),
              ),
              title: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF00FF87).withOpacity(0.15),
                    child: Text(
                      currentUser.name[0].toUpperCase(),
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF00FF87),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentUser.name,
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          currentUser.email,
                          style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(color: Colors.white12, height: 20),
                    Text(
                      'LINKED LOGIN METHODS',
                      style: GoogleFonts.outfit(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    buildMethodRow('Email', Icons.email_outlined, Colors.blueAccent),
                    buildMethodRow('Google', Icons.g_mobiledata_rounded, Colors.redAccent),
                    buildMethodRow('Facebook', Icons.facebook_outlined, const Color(0xFF1877F2)),
                    
                    const Divider(color: Colors.white12, height: 24),
                    Text(
                      'CHANGE PASSWORD',
                      style: GoogleFonts.outfit(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSettingsField(
                      controller: currentPassController,
                      hint: 'Current Password',
                      icon: Icons.lock_outline,
                    ),
                    const SizedBox(height: 8),
                    _buildSettingsField(
                      controller: newPassController,
                      hint: 'New Password',
                      icon: Icons.vpn_key_outlined,
                    ),
                    const SizedBox(height: 8),
                    _buildSettingsField(
                      controller: confirmPassController,
                      hint: 'Confirm New Password',
                      icon: Icons.lock_reset_outlined,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isChangingPassword ? null : handleChangePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00FF87),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isChangingPassword
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Update Password',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close', style: GoogleFonts.outfit(color: Colors.white54)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSettingsField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: controller,
        obscureText: true,
        style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(color: Colors.white30, fontSize: 13),
          prefixIcon: Icon(icon, color: Colors.white30, size: 16),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  void _showClaimDeviceDialog() {
    final idCtrl = TextEditingController(text: '100004');
    final serialCtrl = TextEditingController(text: 'AQ2606004');
    final tokenCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D2018),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Link/Claim Feeder',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idCtrl,
              keyboardType: TextInputType.number,
              style: GoogleFonts.outfit(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Device ID',
                labelStyle: GoogleFonts.outfit(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: serialCtrl,
              style: GoogleFonts.outfit(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Serial Number',
                labelStyle: GoogleFonts.outfit(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: tokenCtrl,
              style: GoogleFonts.outfit(color: Colors.white),
              decoration: InputDecoration(
                labelText: '24h Pairing Token (generated by Admin)',
                labelStyle: GoogleFonts.outfit(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white38))),
          ElevatedButton(
            onPressed: () async {
              final devId = int.tryParse(idCtrl.text.trim());
              final serial = serialCtrl.text.trim();
              final token = tokenCtrl.text.trim();

              if (devId == null || serial.isEmpty || token.isEmpty) {
                _showSnackBar('All fields are required', isError: true);
                return;
              }
              Navigator.pop(ctx);

              try {
                final res = await DeviceService.claimDevice(
                  deviceId: devId,
                  serialNumber: serial,
                  pairingToken: token,
                );
                if (res['success'] == true) {
                  _showSnackBar('Feeder linked successfully! 🎉');
                  _fetchDevices();
                } else {
                  _showSnackBar(res['message'] ?? 'Claim failed', isError: true);
                }
              } catch (_) {
                _showSnackBar('Connection failed', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF87),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Claim Feeder', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
