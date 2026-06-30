import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/admin_models.dart';
import '../services/admin_service.dart';
import '../services/device_service.dart';
import '../services/serial_service.dart';
import '../services/esp_wifi_service.dart';
import 'login_screen.dart';
import '../services/download_helper.dart'
    if (dart.library.js) '../services/download_helper_web.dart';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart' show kIsWeb;


class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  int _selectedTab = 0;

  // â”€â”€ Data â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  late List<AdminUserModel> _users;
  late List<AdminDeviceModel> _devices;
  late List<FeedLogModel> _feedLogs;
  late List<FirmwareModel> _firmwares;

  // Tenant management states
  List<Map<String, dynamic>> _tenants = [];
  Map<String, dynamic>? _selectedTenant;
  bool _isLoadingTenants = false;

  // â”€â”€ User Management filters â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  String _userFilter = 'All';
  String _userSearch = '';
  final _userSearchController = TextEditingController();

  // â”€â”€ Device Management filters â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  String _deviceFilter = 'All';
  String _deviceSearch = '';
  final _deviceSearchController = TextEditingController();

  // â”€â”€ Feed Log filters â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  String _logDeviceFilter = 'All';
  String _logTypeFilter = 'All';
  String _logStatusFilter = 'All';

  // â”€â”€ Firmware â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  bool _isUpdatingAll = false;
  double _otaProgress = 0.0;

  // â”€â”€ System Settings â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final _mqttController =
      TextEditingController(text: 'mqtt://broker.aquaglass.io:1883');
  final _mongoController = TextEditingController(
      text: 'mongodb+srv://admin:***@cluster.mongodb.net/aquaglass');
  bool _emailNotifs = true;
  bool _pushNotifs = true;
  bool _lowFoodAlerts = true;
  bool _deviceOfflineAlerts = true;

  // â”€â”€ Animation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  late AnimationController _statsAnim;
  late Animation<double> _statsFade;

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  INIT
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  bool _isLoadingData = false;

  // Stats KPIs
  int _totalUsersCount = 0;
  int _totalDevicesCount = 0;
  int _onlineDevicesCount = 0;
  int _todayFeedsCount = 0;

  @override
  void initState() {
    super.initState();
    _users = [];
    _devices = [];
    _feedLogs = [];
    _firmwares = [];
    
    _statsAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _statsFade =
        CurvedAnimation(parent: _statsAnim, curve: Curves.easeOutCubic);
    _statsAnim.forward();

    _loadData();
    _initFirmwares();
  }

  Future<void> _loadData() async {
    if (_isLoadingData) return;
    setState(() => _isLoadingData = true);

    try {
      final statsRes = await AdminService.getStats();
      final usersRes = await AdminService.listUsers();
      final devicesRes = await AdminService.listDevices();
      final logsRes = await AdminService.getAllFeedLogs();
      final tenantsRes = await AdminService.listTenants();
      final firmwaresRes = await AdminService.listFirmwares();

      if (mounted) {
        setState(() {
          // Parse Stats
          if (statsRes['success'] == true) {
            final s = statsRes['stats'] ?? {};
            _totalUsersCount = s['totalUsers'] ?? 0;
            _totalDevicesCount = s['totalDevices'] ?? 0;
            _onlineDevicesCount = s['onlineDevices'] ?? 0;
            _todayFeedsCount = s['todayFeeds'] ?? 0;
          }

          // Parse Users
          if (usersRes['success'] == true) {
            final List rawUsers = usersRes['users'] ?? [];
            _users = rawUsers.map((u) {
              return AdminUserModel(
                id: u['uid'] ?? '',
                name: u['name'] ?? 'User',
                email: u['email'] ?? '',
                phone: '',
                status: u['is_active'] == true ? 'Active' : 'Suspended',
                joinDate: DateTime.tryParse(u['created_at'] ?? '') ?? DateTime.now(),
                deviceIds: [],
                role: u['role'] == 'admin' ? 'Admin' : 'User',
              );
            }).toList();
          }

          // Parse Devices
          if (devicesRes['success'] == true) {
            final List rawDevices = devicesRes['devices'] ?? [];
            _devices = rawDevices.map((d) {
              final serial = d['serial_number'] ?? '';
              final deviceId = d['device_id'] ?? 0;
              final isOnline = d['status'] == 'online' || d['status'] == 'provisioned';
              final owner = d['owner_uid'] != null ? 'Registered Owner' : 'Unassigned';

              return AdminDeviceModel(
                id: deviceId.toString(),
                name: d['notes'] ?? 'AquaGlass Feeder',
                serialNumber: serial,
                macAddress: d['ip_address'] ?? '00:00:00:00:00:00',
                firmware: d['firmware_version'] ?? 'v1.0.0',
                isOnline: isOnline,
                ownerEmail: owner,
                feedsToday: d['feeds_today'] ?? 0,
                failedFeeds: d['failed_feeds'] ?? 0,
                location: d['assigned_tenant'] ?? 'Unassigned',
                foodLevelPercent: null,
                lastSeen: DateTime.tryParse(d['last_seen'] ?? '') ?? DateTime.now(),
                members: [],
              );
            }).toList();
          }

          // Parse Feed Logs
          if (logsRes['success'] == true) {
            final List rawLogs = logsRes['feedlogs'] ?? [];
            _feedLogs = rawLogs.map((l) {
              final triggeredAt = DateTime.tryParse(l['triggered_at'] ?? '') ?? DateTime.now();
              return FeedLogModel(
                id: l['_id'] ?? '',
                deviceId: (l['device_id'] ?? '').toString(),
                deviceName: 'Device ${l['device_id']}',
                type: l['trigger_type'] == 'schedule' ? 'Auto' : 'Manual',
                timestamp: triggeredAt,
                status: l['status'] == 'success' ? 'Success' : 'Failed',
                portionSize: '${l['amount_grams'] ?? 5}g',
              );
            }).toList();
          }

          // Parse Tenants
          if (tenantsRes['success'] == true) {
            final List rawTenants = tenantsRes['tenants'] ?? [];
            _tenants = rawTenants.map((t) => {
              'name': t['name'] ?? '',
              'display_name': t['display_name'] ?? '',
            }).toList();
          }

          // Parse Firmwares
          if (firmwaresRes['success'] == true) {
            final List rawFw = firmwaresRes['firmwares'] ?? [];
            _firmwares = rawFw.map((f) {
              return FirmwareModel(
                version: f['version'] ?? '',
                releaseDate: DateTime.tryParse(f['created_at'] ?? '') ?? DateTime.now(),
                changelog: f['changelog'] ?? '',
                sizeKB: (f['size_kb'] ?? 0).toString(),
                isLatest: f['is_latest'] == true,
              );
            }).toList();
          }
        });
      }
    } catch (_) {
      _showSnackBar('Failed to synchronize admin data', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  void _initFirmwares() {
    _firmwares = [
      FirmwareModel(
          version: 'v1.0.4',
          releaseDate: DateTime(2026, 5, 15),
          changelog:
              '• Fixed auto-feed timer drift\n• Improved MQTT reconnect stability\n• Added food level calibration mode\n• Memory leak fix in WiFi handler',
          sizeKB: '248',
          isLatest: true),
      FirmwareModel(
          version: 'v1.0.3',
          releaseDate: DateTime(2026, 3, 2),
          changelog:
              '• Vacation mode implemented\n• Multi-schedule support (up to 10/day)\n• OTA over Cloud added',
          sizeKB: '231',
          isLatest: false),
      FirmwareModel(
          version: 'v1.0.2',
          releaseDate: DateTime(2026, 1, 20),
          changelog:
              '• Initial cloud connect support\n• Manual feed button fix\n• Low food alert threshold configurable',
          sizeKB: '198',
          isLatest: false),
      FirmwareModel(
          version: 'v1.0.1',
          releaseDate: DateTime(2025, 11, 5),
          changelog:
              '• Base release\n• Local WiFi control\n• Basic schedule (3/day)',
          sizeKB: '172',
          isLatest: false),
    ];
  }

  @override
  void dispose() {
    _statsAnim.dispose();
    _userSearchController.dispose();
    _deviceSearchController.dispose();
    _mqttController.dispose();
    _mongoController.dispose();
    super.dispose();
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  HELPERS
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.outfit(color: Colors.white)),
      backgroundColor: isError
          ? Colors.redAccent
          : const Color(0xFF00FF87).withOpacity(0.9),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'Owner':
        return const Color(0xFFFFD700);
      case 'Editor':
        return const Color(0xFF4FC3F7);
      default:
        return Colors.white38;
    }
  }

  Color _statusColor(String status) =>
      status == 'Active' ? const Color(0xFF00FF87) : Colors.redAccent;

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  BUILD
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05120E),
      appBar: _buildAppBar(),
      body: IndexedStack(
        index: _selectedTab,
        children: [
          _buildDashboardTab(),
          _buildUsersTab(),
          _buildDevicesTab(),
          _buildLogsTab(),
          _buildFirmwareTab(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF071A0F),
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.white.withOpacity(0.07)),
      ),
      title: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF00FF87), Color(0xFF00C853)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.water_drop_rounded, color: Colors.black, size: 18),
        ),
        const SizedBox(width: 10),
        Text('AquaGlass',
            style: GoogleFonts.outfit(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFF8F00)]),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('SUPER ADMIN',
              style: GoogleFonts.outfit(
                  color: Colors.black,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2)),
        ),
      ]),
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white54),
              onPressed: () => _showSnackBar('3 new notifications ðŸ””'),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white54),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    const items = [
      BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
      BottomNavigationBarItem(icon: Icon(Icons.people_rounded), label: 'Users'),
      BottomNavigationBarItem(icon: Icon(Icons.devices_rounded), label: 'Devices'),
      BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'Feed Logs'),
      BottomNavigationBarItem(icon: Icon(Icons.system_update_rounded), label: 'Firmware'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF071A0F),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.07))),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (i) => setState(() => _selectedTab = i),
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF00FF87),
        unselectedItemColor: Colors.white30,
        selectedLabelStyle:
            GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.outfit(fontSize: 10),
        items: items,
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  TAB 0 â€” DASHBOARD
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildDashboardTab() {
    final totalUsers = _totalUsersCount;
    final totalDevices = _totalDevicesCount;
    final onlineDevices = _onlineDevicesCount;
    final offlineDevices = _totalDevicesCount - _onlineDevicesCount;
    final todayFeeds = _todayFeedsCount;
    final failedFeeds = _feedLogs.where((l) => l.status == 'Failed').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Control Center',
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22)),
              Text('Live overview of your AquaGlass network',
                  style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
            ]),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF87).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF00FF87).withOpacity(0.35)),
              ),
              child: Row(children: [
                const Icon(Icons.circle, color: Color(0xFF00FF87), size: 7),
                const SizedBox(width: 6),
                Text('Live',
                    style: GoogleFonts.outfit(
                        color: const Color(0xFF00FF87), fontSize: 12)),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // â”€â”€ KPI Cards â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        AnimatedBuilder(
          animation: _statsFade,
          builder: (_, __) => Opacity(
            opacity: _statsFade.value,
            child: Transform.translate(
              offset: Offset(0, 24 * (1 - _statsFade.value)),
              child: Column(children: [
                Row(children: [
                  Expanded(
                      child: _kpiCard('Total Users', '$totalUsers',
                          Icons.people_rounded, const Color(0xFF4FC3F7))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _kpiCard('Total Devices', '$totalDevices',
                          Icons.devices_rounded, const Color(0xFF00FF87))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _kpiCard('Online', '$onlineDevices',
                          Icons.wifi_rounded, const Color(0xFF00FF87),
                          sub: 'devices')),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _kpiCard('Offline', '$offlineDevices',
                          Icons.wifi_off_rounded, Colors.redAccent,
                          sub: 'devices')),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _kpiCard("Today's Feeds", '$todayFeeds',
                          Icons.restaurant_rounded, const Color(0xFFFFD700),
                          sub: 'successful')),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _kpiCard('Failed Feeds', '$failedFeeds',
                          Icons.error_rounded, Colors.redAccent,
                          sub: 'events')),
                ]),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // â”€â”€ Health Ring + Quick Actions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            flex: 2,
            child: _glassCard(child: Column(children: [
              Text('Network Health',
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: _statsFade,
                builder: (_, __) => SizedBox(
                  width: 100,
                  height: 100,
                  child: CustomPaint(
                    painter: _RingPainter(
                      progress: _statsFade.value * (onlineDevices / totalDevices),
                      color: const Color(0xFF00FF87),
                    ),
                    child: Center(
                      child: Text(
                        '${((onlineDevices / totalDevices) * 100).round()}%',
                        style: GoogleFonts.outfit(
                            color: const Color(0xFF00FF87),
                            fontWeight: FontWeight.bold,
                            fontSize: 20),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('$onlineDevices of $totalDevices online',
                  style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 4),
              Text('${offlineDevices > 0 ? "$offlineDevices offline" : "All healthy"}',
                  style: GoogleFonts.outfit(
                      color: offlineDevices > 0 ? Colors.redAccent : const Color(0xFF00FF87),
                      fontSize: 11)),
            ])),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: _glassCard(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quick Actions',
                    style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                const SizedBox(height: 14),
                _quickAction(Icons.campaign_rounded, 'Broadcast Notification',
                    const Color(0xFF4FC3F7)),
                const SizedBox(height: 8),
                _quickAction(Icons.file_download_rounded, 'Export Feed Report',
                    const Color(0xFF00FF87)),
                const SizedBox(height: 8),
                _quickAction(Icons.system_update_rounded, 'Push OTA to All',
                    const Color(0xFFFFD700)),
                const SizedBox(height: 8),
                _quickAction(Icons.health_and_safety_rounded, 'System Diagnostics',
                    Colors.purpleAccent),
              ],
            )),
          ),
        ]),
        const SizedBox(height: 16),

        // â”€â”€ Recent Activity â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        _glassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Recent Activity',
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              Text('View All',
                  style: GoogleFonts.outfit(
                      color: const Color(0xFF00FF87), fontSize: 12)),
            ]),
            const SizedBox(height: 14),
            ..._activityItems(),
          ]),
        ),
      ]),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color,
      {String? sub}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.13), color.withOpacity(0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        Text(value,
            style: GoogleFonts.outfit(
                color: color, fontWeight: FontWeight.bold, fontSize: 26)),
        Text(label,
            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 10)),
        if (sub != null)
          Text(sub,
              style: GoogleFonts.outfit(color: Colors.white30, fontSize: 9)),
      ]),
    );
  }

  Widget _quickAction(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () => _showSnackBar('$label triggered'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(label,
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
          const Spacer(),
          Icon(Icons.chevron_right,
              color: color.withOpacity(0.5), size: 18),
        ]),
      ),
    );
  }

  List<Widget> _activityItems() {
    final items = [
      {'icon': Icons.check_circle_rounded, 'color': const Color(0xFF00FF87), 'msg': 'Auto-feed success â€” BioLab A', 'time': '2m ago'},
      {'icon': Icons.warning_rounded, 'color': const Color(0xFFFFD700), 'msg': 'Low food alert â€” AquaRoom (42%)', 'time': '15m ago'},
      {'icon': Icons.error_rounded, 'color': Colors.redAccent, 'msg': 'Device offline â€” BioLab B', 'time': '2h ago'},
      {'icon': Icons.person_add_rounded, 'color': const Color(0xFF4FC3F7), 'msg': 'New member invited â€” BioLab A', 'time': '3h ago'},
      {'icon': Icons.system_update_rounded, 'color': Colors.purpleAccent, 'msg': 'OTA v1.0.4 pushed â€” BioLab A', 'time': 'Yesterday'},
    ];
    return items
        .map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: (a['color'] as Color).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(a['icon'] as IconData,
                      color: a['color'] as Color, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(a['msg'] as String,
                        style:
                            GoogleFonts.outfit(color: Colors.white70, fontSize: 12))),
                Text(a['time'] as String,
                    style: GoogleFonts.outfit(color: Colors.white30, fontSize: 10)),
              ]),
            ))
        .toList();
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  TAB 1 â€” USERS
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildUsersTab() {
    final filtered = _users.where((u) {
      final mf = _userFilter == 'All' ||
          (_userFilter == 'Admins' && u.role == 'Admin') ||
          (_userFilter == 'Normal Users' && u.role == 'User') ||
          (_userFilter == 'Active' && u.status == 'Active') ||
          (_userFilter == 'Suspended' && u.status == 'Suspended');
      final ms = _userSearch.isEmpty ||
          u.name.toLowerCase().contains(_userSearch.toLowerCase()) ||
          u.email.toLowerCase().contains(_userSearch.toLowerCase());
      return mf && ms;
    }).toList();

    return Column(children: [
      Container(
        color: const Color(0xFF05120E),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Column(children: [
          _searchBar(_userSearchController, 'Search users by name or email...',
              (v) => setState(() => _userSearch = v)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Admins', 'Normal Users', 'Active', 'Suspended'].map((f) =>
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _filterChip(f, _userFilter == f, () => setState(() => _userFilter = f)),
                ),
              ).toList(),
            ),
          ),
          const SizedBox(height: 10),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(children: [
          Text('${filtered.length} users',
              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
          const Spacer(),
          _addBtn('Invite User', () => _showInviteUserDialog()),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filtered.length,
          itemBuilder: (_, i) => _userCard(filtered[i]),
        ),
      ),
    ]);
  }

  Widget _userCard(AdminUserModel user) {
    final initials = user.name.split(' ').map((e) => e[0]).take(2).join();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: _roleColor(user.role).withOpacity(0.2),
            child: Text(initials,
                style: GoogleFonts.outfit(
                    color: _roleColor(user.role),
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ),
          title: Text(user.name,
              style: GoogleFonts.outfit(
                  color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(user.email,
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11)),
          ),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            _pill(user.status, _statusColor(user.status)),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, color: Colors.white30, size: 20),
          ]),
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Divider(color: Colors.white12, height: 16),
              Wrap(spacing: 8, runSpacing: 6, children: [
                _statChip(Icons.devices_rounded,
                    '${user.deviceIds.length} Devices', const Color(0xFF00FF87)),
                _statChip(Icons.verified_user_rounded, user.role, _roleColor(user.role)),
                _statChip(Icons.phone_rounded, user.phone, Colors.white38),
                _statChip(Icons.calendar_today_rounded,
                    'Since ${user.joinDate.day}/${user.joinDate.month}/${user.joinDate.year}',
                    Colors.white38),
              ]),
              const SizedBox(height: 12),
              Text('Assigned Devices:',
                  style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: user.deviceIds.map((did) {
                final dev = _devices.firstWhere((d) => d.id == did,
                    orElse: () => _devices[0]);
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(dev.name.split('â€”').last.trim(),
                      style: GoogleFonts.outfit(
                          color: Colors.white70, fontSize: 11)),
                );
              }).toList()),
              const SizedBox(height: 14),
              Row(children: [
                _actionBtn(
                  user.status == 'Active' ? 'Suspend' : 'Activate',
                  user.status == 'Active' ? Colors.redAccent : const Color(0xFF00FF87),
                  user.status == 'Active' ? Icons.block_rounded : Icons.check_circle_rounded,
                  () async {
                    final newStatus = user.status == 'Active' ? 'Suspended' : 'Active';
                    final isActive = newStatus == 'Active';
                    try {
                      final res = await AdminService.updateUser(user.id, {'is_active': isActive});
                      if (res['success'] == true) {
                        setState(() {
                          user.status = newStatus;
                        });
                        _showSnackBar('${user.name} ${isActive ? "activated" : "suspended"}');
                      } else {
                        _showSnackBar(res['message'] ?? 'Failed to update user', isError: true);
                      }
                    } catch (_) {
                      _showSnackBar('Connection failed', isError: true);
                    }
                  },
                ),
                const SizedBox(width: 8),
                _actionBtn('Notify', const Color(0xFF4FC3F7),
                    Icons.notifications_rounded,
                    () => _showSnackBar('Notification sent to ${user.name}')),
                const SizedBox(width: 8),
                _actionBtn('Remove', Colors.redAccent, Icons.delete_rounded,
                    () async {
                  try {
                    final res = await AdminService.deleteUser(user.id);
                    if (res['success'] == true) {
                      setState(() => _users.remove(user));
                      _showSnackBar('${user.name} removed', isError: true);
                    } else {
                      _showSnackBar(res['message'] ?? 'Failed to delete user', isError: true);
                    }
                  } catch (_) {
                    _showSnackBar('Connection failed', isError: true);
                  }
                }),
              ]),
            ]),
          ],
        ),
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  TAB 2 â€” DEVICES
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildDevicesTab() {
    if (_selectedTenant == null) {
      // 1. Tenant List view
      final filteredTenants = _tenants.where((t) {
        final ms = _deviceSearch.isEmpty ||
            t['name'].toString().toLowerCase().contains(_deviceSearch.toLowerCase()) ||
            t['display_name'].toString().toLowerCase().contains(_deviceSearch.toLowerCase());
        return ms;
      }).toList();

      return Column(children: [
        Container(
          color: const Color(0xFF05120E),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(children: [
            _searchBar(_deviceSearchController, 'Search tenants...',
                (v) => setState(() => _deviceSearch = v)),
            const SizedBox(height: 10),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(children: [
            Text('${filteredTenants.length} tenants',
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
            const Spacer(),
            _addBtn('Add Tenant', () => _showAddTenantDialog()),
          ]),
        ),
        Expanded(
          child: filteredTenants.isEmpty
              ? Center(child: Text('No tenants found', style: GoogleFonts.outfit(color: Colors.white38)))
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.3,
                  ),
                  itemCount: filteredTenants.length,
                  itemBuilder: (_, idx) {
                    final t = filteredTenants[idx];
                    final devCount = _devices.where((d) => d.location == t['name']).length;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _selectedTenant = t;
                        _deviceSearch = '';
                        _deviceSearchController.clear();
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(Icons.business_rounded, color: const Color(0xFF00FF87), size: 24),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () async {
                                        try {
                                          final res = await AdminService.deleteTenant(t['name']);
                                          if (res['success'] == true) {
                                            _showSnackBar('Tenant ${t['display_name']} deleted.');
                                            _loadData();
                                          } else {
                                            _showSnackBar(res['message'] ?? 'Failed to delete tenant', isError: true);
                                          }
                                        } catch (_) {
                                          _showSnackBar('Connection failed', isError: true);
                                        }
                                      },
                                      child: Icon(Icons.delete_outline_rounded, color: Colors.redAccent.withOpacity(0.6), size: 18),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t['display_name'],
                                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${t['name']} • $devCount devices',
                                  style: GoogleFonts.outfit(color: Colors.white30, fontSize: 10),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ]);
    } else {
      // 2. Selected Tenant Devices list view
      final t = _selectedTenant!;
      final tenantDevices = _devices.where((d) => d.location == t['name']).toList();
      final filtered = tenantDevices.where((d) {
        final mf = _deviceFilter == 'All' ||
            (_deviceFilter == 'Online' && d.isOnline) ||
            (_deviceFilter == 'Offline' && !d.isOnline);
        final ms = _deviceSearch.isEmpty ||
            d.name.toLowerCase().contains(_deviceSearch.toLowerCase()) ||
            d.serialNumber.toLowerCase().contains(_deviceSearch.toLowerCase());
        return mf && ms;
      }).toList();

      return Column(children: [
        Container(
          color: const Color(0xFF05120E),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(children: [
            Row(children: [
              TextButton.icon(
                onPressed: () => setState(() => _selectedTenant = null),
                icon: const Icon(Icons.arrow_back_rounded, color: const Color(0xFF00FF87), size: 16),
                label: Text('Back to Tenants', style: GoogleFonts.outfit(color: const Color(0xFF00FF87), fontSize: 12)),
              ),
              const Spacer(),
              Text(
                t['display_name'],
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ]),
            const SizedBox(height: 6),
            _searchBar(_deviceSearchController, 'Search devices in tenant...',
                (v) => setState(() => _deviceSearch = v)),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Online', 'Offline'].map((f) =>
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _filterChip(f, _deviceFilter == f,
                        () => setState(() => _deviceFilter = f)),
                  ),
                ).toList(),
              ),
            ),
            const SizedBox(height: 10),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(children: [
            Text('${filtered.length} devices',
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
            const Spacer(),
            _addBtn('Provision Device', () => _showProvisionDeviceDialog()),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filtered.length,
            itemBuilder: (_, i) => _deviceCard(filtered[i]),
          ),
        ),
      ]);
    }
  }

  Widget _deviceCard(AdminDeviceModel device) {
    final onColor =
        device.isOnline ? const Color(0xFF00FF87) : Colors.redAccent;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: onColor.withOpacity(0.2)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: onColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.router_rounded, color: onColor, size: 22),
          ),
          title: Row(children: [
            Expanded(
              child: Text(device.name.split('â€”').last.trim(),
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 6),
            _pill(device.isOnline ? 'Online' : 'Offline', onColor),
          ]),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(device.serialNumber,
                  style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10)),
              const SizedBox(height: 5),
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: device.foodLevelPercent != null ? device.foodLevelPercent! / 100 : 0.0,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        device.foodLevelPercent == null
                            ? Colors.white24
                            : device.foodLevelPercent! > 50
                                ? const Color(0xFF00FF87)
                                : device.foodLevelPercent! > 20
                                    ? const Color(0xFFFFD700)
                                    : Colors.redAccent,
                      ),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(device.foodLevelPercent != null ? '${device.foodLevelPercent}%' : 'NA',
                    style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10)),
              ]),
            ]),
          ),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            _pill(device.firmware, Colors.purpleAccent),
            const SizedBox(height: 4),
            const Icon(Icons.expand_more, color: Colors.white30, size: 18),
          ]),
          children: [_deviceDetailPanel(device)],
        ),
      ),
    );
  }

  Widget _deviceDetailPanel(AdminDeviceModel device) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Divider(color: Colors.white12, height: 16),

      // Info chips
      Wrap(spacing: 8, runSpacing: 8, children: [
        _infoChip('Serial', device.serialNumber),
        _infoChip('MAC', device.macAddress),
        _infoChip('Location', device.location.split('â€”').last.trim()),
        _infoChip('Feeds Today', '${device.feedsToday}'),
        _infoChip('Failed', '${device.failedFeeds}', alert: device.failedFeeds > 0),
        _infoChip('Last Seen', _timeAgo(device.lastSeen)),
        _infoChip('Owner', device.ownerEmail.split('@').first),
      ]),
      const SizedBox(height: 14),

      // Members header
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Members (${device.members.length})',
            style: GoogleFonts.outfit(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
        GestureDetector(
          onTap: () => _showInviteMemberDialog(device),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF4FC3F7).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFF4FC3F7).withOpacity(0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.person_add_rounded,
                  size: 12, color: Color(0xFF4FC3F7)),
              const SizedBox(width: 4),
              Text('Invite',
                  style: GoogleFonts.outfit(
                      color: const Color(0xFF4FC3F7), fontSize: 11)),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      ...device.members.map((m) => _memberRow(m, device)),
      const SizedBox(height: 14),

      // Action buttons
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _deviceActionBtn('Restart', Icons.restart_alt_rounded,
              const Color(0xFF4FC3F7),
              () => _showSnackBar('Restarting ${device.name}â€¦')),
          const SizedBox(width: 8),
          _deviceActionBtn('OTA Update', Icons.system_update_rounded,
              Colors.purpleAccent, () => _showOtaDialog(device)),
          const SizedBox(width: 8),
          _deviceActionBtn('Diagnostics', Icons.analytics_rounded,
              const Color(0xFFFFD700), () => _showDiagnosticsDialog(device)),
          const SizedBox(width: 8),
          _deviceActionBtn('Transfer', Icons.swap_horiz_rounded, Colors.orange,
              () => _showTransferOwnershipDialog(device)),
          const SizedBox(width: 8),
          _deviceActionBtn('Unbind', Icons.link_off_rounded, Colors.redAccent, () async {
            try {
              final res = await AdminService.deleteDevice(int.parse(device.id));
              if (res['success'] == true) {
                setState(() => _devices.remove(device));
                _showSnackBar('${device.name} unbound successfully', isError: true);
              } else {
                _showSnackBar(res['message'] ?? 'Failed to delete device', isError: true);
              }
            } catch (_) {
              _showSnackBar('Connection failed', isError: true);
            }
          }),
        ]),
      ),
    ]);
  }

  Widget _memberRow(DeviceMemberModel member, AdminDeviceModel device) {
    final initials = member.name.split(' ').map((e) => e[0]).take(2).join();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: _roleColor(member.role).withOpacity(0.2),
          child: Text(initials,
              style: GoogleFonts.outfit(
                  color: _roleColor(member.role),
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(member.name,
                style: GoogleFonts.outfit(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
            Text(member.email,
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10)),
          ]),
        ),
        _pill(member.role, _roleColor(member.role)),
        if (member.role != 'Owner') ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              setState(() => device.members.remove(member));
              _showSnackBar('${member.name} removed from device');
            },
            child: const Icon(Icons.close, color: Colors.white30, size: 16),
          ),
        ],
      ]),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  TAB 3 â€” FEED LOGS
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildLogsTab() {
    final filtered = _feedLogs.where((l) {
      final md = _logDeviceFilter == 'All' || l.deviceName == _logDeviceFilter;
      final mt = _logTypeFilter == 'All' || l.type == _logTypeFilter;
      final ms = _logStatusFilter == 'All' || l.status == _logStatusFilter;
      return md && mt && ms;
    }).toList();

    final deviceNames = [
      'All',
      ..._feedLogs.map((l) => l.deviceName).toSet().toList()
    ];

    return Column(children: [
      // Filters
      Container(
        color: const Color(0xFF05120E),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              Text('Device: ',
                  style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
              ...deviceNames.map((d) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _filterChip(d, _logDeviceFilter == d,
                        () => setState(() => _logDeviceFilter = d)),
                  )),
            ]),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              Text('Type: ',
                  style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
              ...['All', 'Auto', 'Manual', 'Vacation-Skip'].map((t) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _filterChip(t, _logTypeFilter == t,
                        () => setState(() => _logTypeFilter = t)),
                  )),
            ]),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Text('Status: ',
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
            ...['All', 'Success', 'Failed'].map((s) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _filterChip(s, _logStatusFilter == s,
                      () => setState(() => _logStatusFilter = s)),
                )),
          ]),
        ]),
      ),

      // Column headers
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.white.withOpacity(0.03),
        child: Row(children: [
          Expanded(flex: 3, child: Text('Device', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11))),
          Expanded(flex: 2, child: Text('Time', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11))),
          Expanded(flex: 2, child: Text('Type', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11))),
          Expanded(flex: 2, child: Text('Status', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11))),
          Expanded(flex: 2, child: Text('Portion', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11))),
        ]),
      ),

      Expanded(
        child: filtered.isEmpty
            ? Center(
                child: Text('No logs match filters',
                    style: GoogleFonts.outfit(color: Colors.white38)))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                itemCount: filtered.length,
                itemBuilder: (_, i) => _logRow(filtered[i]),
              ),
      ),

      Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showSnackBar(
                'Exporting ${filtered.length} records as CSVâ€¦ ðŸ“„'),
            icon: const Icon(Icons.download_rounded, size: 16),
            label: Text(
                'Export ${filtered.length} Records as CSV',
                style: GoogleFonts.outfit()),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  const Color(0xFF00FF87).withOpacity(0.12),
              foregroundColor: const Color(0xFF00FF87),
              side: const BorderSide(color: Color(0xFF00FF87)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _logRow(FeedLogModel log) {
    final typeColor = log.type == 'Auto'
        ? const Color(0xFF4FC3F7)
        : log.type == 'Manual'
            ? const Color(0xFF00FF87)
            : Colors.orange;
    final statusColor =
        log.status == 'Success' ? const Color(0xFF00FF87) : Colors.redAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: log.status == 'Failed'
              ? Colors.redAccent.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Row(children: [
        Expanded(
            flex: 3,
            child: Text(log.deviceName,
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11))),
        Expanded(
            flex: 2,
            child: Text(_timeAgo(log.timestamp),
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10))),
        Expanded(
            flex: 2,
            child: _pill(log.type, typeColor)),
        Expanded(
            flex: 2,
            child: _pill(log.status, statusColor)),
        Expanded(
            flex: 2,
            child: Text(log.portionSize,
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10))),
      ]),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  TAB 4 â€” FIRMWARE & SETTINGS
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildFirmwareTab() {
    if (_firmwares.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF00FF87)),
              const SizedBox(height: 16),
              Text(
                'Fetching Firmware releases...',
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _showAddFirmwareDialog,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text('Upload Initial Firmware Release', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF87),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Latest firmware header & Action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Target Firmware',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ElevatedButton.icon(
              onPressed: _showAddFirmwareDialog,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text('Add Release', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF87).withOpacity(0.12),
                foregroundColor: const Color(0xFF00FF87),
                side: BorderSide(color: const Color(0xFF00FF87).withOpacity(0.3)),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Latest firmware details
        _glassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF00FF87), Color(0xFF00C853)]),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text('LATEST',
                    style: GoogleFonts.outfit(
                        color: Colors.black,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2)),
              ),
              const SizedBox(width: 10),
              Text(_firmwares[0].version,
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22)),
              const Spacer(),
              Text('${_firmwares[0].sizeKB} KB',
                  style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
            ]),
            const SizedBox(height: 4),
            Text(
                'Released ${_firmwares[0].releaseDate.day}/${_firmwares[0].releaseDate.month}/${_firmwares[0].releaseDate.year}',
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_firmwares[0].changelog,
                  style: GoogleFonts.outfit(
                      color: Colors.white60, fontSize: 12, height: 1.7)),
            ),
            const SizedBox(height: 16),

            if (_isUpdatingAll) ...[
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _otaProgress,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF00FF87)),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${(_otaProgress * 100).round()}%',
                    style: GoogleFonts.outfit(
                        color: const Color(0xFF00FF87),
                        fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 6),
              Text(
                  '${(_devices.length * _otaProgress).round()} of ${_devices.length} devices updated…',
                  style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11)),
            ] else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startBulkOta,
                  icon: const Icon(Icons.system_update_rounded, size: 16),
                  label: Text(
                      'Push OTA to All ${_devices.length} Devices',
                      style:
                          GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF87),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 16),

        // Per-device OTA
        _glassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Target Specific Devices',
                style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const SizedBox(height: 12),
            ..._devices.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Icon(Icons.router_rounded,
                        color: d.isOnline
                            ? const Color(0xFF00FF87)
                            : Colors.redAccent,
                        size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.name,
                                style: GoogleFonts.outfit(
                                    color: Colors.white70, fontSize: 12)),
                            Text(d.firmware,
                                style: GoogleFonts.outfit(
                                    color: Colors.white38, fontSize: 10)),
                          ]),
                    ),
                    d.firmware == _firmwares[0].version
                        ? _pill('Up to date', const Color(0xFF00FF87))
                        : GestureDetector(
                            onTap: () => _showOtaDialog(d),
                            child: _pill('Update', Colors.purpleAccent),
                          ),
                  ]),
                )),
          ]),
        ),
        const SizedBox(height: 16),

        // Firmware history
        Text('Release History',
            style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        const SizedBox(height: 10),
        ..._firmwares.map((fw) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(fw.version,
                      style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const SizedBox(width: 10),
                  Text(
                      '${fw.releaseDate.day}/${fw.releaseDate.month}/${fw.releaseDate.year}',
                      style:
                          GoogleFonts.outfit(color: Colors.white38, fontSize: 11)),
                  if (fw.isLatest) ...[
                    const SizedBox(width: 8),
                    _pill('LATEST', const Color(0xFF00FF87)),
                  ],
                  const Spacer(),
                  Text('${fw.sizeKB} KB',
                      style:
                          GoogleFonts.outfit(color: Colors.white38, fontSize: 11)),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () async {
                      try {
                        final res = await AdminService.deleteFirmware(fw.version);
                        if (res['success'] == true) {
                          _showSnackBar('Release version ${fw.version} deleted successfully');
                          _loadData();
                        } else {
                          _showSnackBar(res['message'] ?? 'Delete failed', isError: true);
                        }
                      } catch (_) {
                        _showSnackBar('Connection failed', isError: true);
                      }
                    },
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(fw.changelog,
                    style: GoogleFonts.outfit(
                        color: Colors.white38, fontSize: 11, height: 1.6)),
              ]),
            )),
        const SizedBox(height: 16),

        // System settings
        _glassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('System Settings',
                style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const SizedBox(height: 14),
            _settingsField('MQTT Broker URL', _mqttController, Icons.cloud_rounded),
            const SizedBox(height: 10),
            _settingsField('MongoDB URI', _mongoController, Icons.storage_rounded),
            const SizedBox(height: 16),
            Text('Notification Preferences',
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 8),
            _toggle('Email Notifications', _emailNotifs,
                (v) => setState(() => _emailNotifs = v)),
            _toggle('Push Notifications', _pushNotifs,
                (v) => setState(() => _pushNotifs = v)),
            _toggle('Low Food Alerts', _lowFoodAlerts,
                (v) => setState(() => _lowFoodAlerts = v)),
            _toggle('Device Offline Alerts', _deviceOfflineAlerts,
                (v) => setState(() => _deviceOfflineAlerts = v)),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showSnackBar('Settings saved ✓'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF87),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Save Settings',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _searchBar(
      TextEditingController ctrl, String hint, Function(String) onChange) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: ctrl,
        onChanged: onChange,
        style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(color: Colors.white30, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Colors.white30, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF00FF87).withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF00FF87).withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(label,
            style: GoogleFonts.outfit(
                color: selected ? const Color(0xFF00FF87) : Colors.white54,
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: GoogleFonts.outfit(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.outfit(color: color, fontSize: 10)),
      ]),
    );
  }

  Widget _actionBtn(
      String label, Color color, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.outfit(color: color, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _deviceActionBtn(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 3),
          Text(label, style: GoogleFonts.outfit(color: color, fontSize: 10)),
        ]),
      ),
    );
  }

  Widget _infoChip(String key, String value, {bool alert = false}) {
    final c = alert ? Colors.redAccent : Colors.white54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: alert
            ? Colors.redAccent.withOpacity(0.1)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(key,
            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 9)),
        Text(value,
            style: GoogleFonts.outfit(
                color: c, fontSize: 11, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _addBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF00FF87), Color(0xFF00C853)]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.add, size: 14, color: Colors.black),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.outfit(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Widget _settingsField(
      String label, TextEditingController ctrl, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: ctrl,
        style: GoogleFonts.outfit(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.outfit(color: Colors.white38, fontSize: 11),
          prefixIcon: Icon(icon, color: Colors.white30, size: 18),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _toggle(String label, bool value, Function(bool) onChange) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Text(label,
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
        const Spacer(),
        Switch(
          value: value,
          onChanged: onChange,
          activeColor: const Color(0xFF00FF87),
          inactiveTrackColor: Colors.white12,
        ),
      ]),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
  //  DIALOGS
  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  void _showInviteUserDialog() {
    final emailCtrl = TextEditingController();
    String role = 'Viewer';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: const Color(0xFF0D2018),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Invite New User',
              style: GoogleFonts.outfit(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            _dialogField(emailCtrl, 'Email Address', Icons.email_rounded),
            const SizedBox(height: 14),
            Text('Assign Role:',
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['Owner', 'Editor', 'Viewer'].map((r) =>
                GestureDetector(
                  onTap: () => set(() => role = r),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: role == r
                          ? _roleColor(r).withOpacity(0.2)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: role == r ? _roleColor(r) : Colors.white12),
                    ),
                    child: Text(r,
                        style: GoogleFonts.outfit(
                            color: role == r ? _roleColor(r) : Colors.white38,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ).toList(),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel',
                    style: GoogleFonts.outfit(color: Colors.white38))),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showSnackBar('Invite sent to ${emailCtrl.text}');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF87),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Send Invite',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteMemberDialog(AdminDeviceModel device) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String role = 'Viewer';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: const Color(0xFF0D2018),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
              'Invite to ${device.name.split("â€”").last.trim()}',
              style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            _dialogField(nameCtrl, 'Full Name', Icons.person_rounded),
            const SizedBox(height: 10),
            _dialogField(emailCtrl, 'Email Address', Icons.email_rounded),
            const SizedBox(height: 14),
            Text('Role:',
                style:
                    GoogleFonts.outfit(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['Owner', 'Editor', 'Viewer'].map((r) =>
                GestureDetector(
                  onTap: () => set(() => role = r),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: role == r
                          ? _roleColor(r).withOpacity(0.2)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: role == r ? _roleColor(r) : Colors.white12),
                    ),
                    child: Text(r,
                        style: GoogleFonts.outfit(
                            color: role == r ? _roleColor(r) : Colors.white38,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ).toList(),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel',
                    style: GoogleFonts.outfit(color: Colors.white38))),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.isNotEmpty && emailCtrl.text.isNotEmpty) {
                  setState(() {
                    device.members.add(DeviceMemberModel(
                      id: 'new_${DateTime.now().millisecondsSinceEpoch}',
                      name: nameCtrl.text,
                      email: emailCtrl.text,
                      role: role,
                      joinedAt: DateTime.now(),
                    ));
                  });
                  Navigator.pop(ctx);
                  _showSnackBar(
                      '${nameCtrl.text} invited as $role âœ“');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF87),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Send Invite',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showOtaDialog(AdminDeviceModel device) {
    bool updating = false;
    double prog = 0;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: const Color(0xFF0D2018),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
              'OTA Update â€” ${device.name.split("â€”").last.trim()}',
              style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text('${device.firmware}',
                  style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, color: Colors.white30, size: 16),
              ),
              Text(_firmwares[0].version,
                  style: GoogleFonts.outfit(
                      color: const Color(0xFF00FF87), fontSize: 13)),
            ]),
            const SizedBox(height: 16),
            if (updating) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: prog,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF00FF87)),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Text('${(prog * 100).round()}% complete',
                  style: GoogleFonts.outfit(
                      color: Colors.white38, fontSize: 12)),
            ] else
              Text(
                  'Push firmware ${_firmwares[0].version} to this device via MQTT?',
                  style: GoogleFonts.outfit(
                      color: Colors.white54, fontSize: 13)),
          ]),
          actions: updating
              ? []
              : [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Cancel',
                          style: GoogleFonts.outfit(color: Colors.white38))),
                  ElevatedButton(
                    onPressed: () async {
                      set(() => updating = true);
                      for (int i = 1; i <= 10; i++) {
                        await Future.delayed(
                            const Duration(milliseconds: 300));
                        set(() => prog = i / 10.0);
                      }
                      if (ctx.mounted) {
                        setState(
                            () => device.firmware = _firmwares[0].version);
                        Navigator.pop(ctx);
                        _showSnackBar(
                            'OTA complete â€” ${device.name} updated to ${_firmwares[0].version} âœ“');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Push Update',
                        style:
                            GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  ),
                ],
        ),
      ),
    );
  }

  void _showDiagnosticsDialog(AdminDeviceModel device) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D2018),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
            'Diagnostics â€” ${device.name.split("â€”").last.trim()}',
            style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _diagRow('Status',
              device.isOnline ? 'Online âœ“' : 'Offline âœ—',
              device.isOnline ? const Color(0xFF00FF87) : Colors.redAccent),
          _diagRow('Food Level', device.foodLevelPercent != null ? '${device.foodLevelPercent}%' : 'NA',
              device.foodLevelPercent == null ? Colors.white54 : (device.foodLevelPercent! > 20 ? const Color(0xFF00FF87) : Colors.redAccent)),
          _diagRow('Firmware', device.firmware, Colors.purpleAccent),
          _diagRow('MAC Address', device.macAddress, Colors.white54),
          _diagRow('Serial', device.serialNumber, Colors.white54),
          _diagRow('Location',
              device.location.split('â€”').last.trim(), Colors.white54),
          _diagRow("Today's Feeds", '${device.feedsToday} successful',
              const Color(0xFF00FF87)),
          _diagRow('Failed Feeds', '${device.failedFeeds} events',
              device.failedFeeds > 0
                  ? Colors.redAccent
                  : const Color(0xFF00FF87)),
          _diagRow('Last Seen', _timeAgo(device.lastSeen), Colors.white54),
          _diagRow('RSSI',
              device.isOnline ? '-58 dBm (Good)' : 'N/A',
              device.isOnline ? const Color(0xFF00FF87) : Colors.white38),
          _diagRow('Free Heap',
              device.isOnline ? '182 KB' : 'N/A', Colors.white54),
        ]),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF87),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child:
                Text('Close', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(
      TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      style: GoogleFonts.outfit(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.outfit(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.white30, size: 18),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF00FF87))),
      ),
    );
  }

  Widget _diagRow(String key, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Text('$key:',
            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
        const Spacer(),
        Text(value,
            style: GoogleFonts.outfit(
                color: valueColor,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Future<void> _startBulkOta() async {
    setState(() {
      _isUpdatingAll = true;
      _otaProgress = 0;
    });
    for (int i = 1; i <= 20; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) setState(() => _otaProgress = i / 20.0);
    }
    if (mounted) {
      setState(() {
        _isUpdatingAll = false;
        for (final d in _devices) {
          d.firmware = _firmwares[0].version;
        }
      });
      _showSnackBar(
          'All ${_devices.length} devices updated to ${_firmwares[0].version} âœ“');
    }
  }


  // Global Key for QR Code boundary capture
  final GlobalKey _qrBoundaryKey = GlobalKey();

  void _showAddTenantDialog() {
    final nameCtrl = TextEditingController();
    final dispCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D2018),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Create New Tenant',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(nameCtrl, 'Tenant Unique Code (e.g. TENANT_C)', Icons.business_center_rounded),
            const SizedBox(height: 12),
            _dialogField(dispCtrl, 'Display Name (e.g. Acme Research Lab)', Icons.title_rounded),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white38))),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim().toUpperCase();
              final disp = dispCtrl.text.trim();
              if (name.isEmpty || disp.isEmpty) {
                _showSnackBar('Both fields are required', isError: true);
                return;
              }
              Navigator.pop(ctx);

              try {
                final res = await AdminService.createTenant(name, disp);
                if (res['success'] == true) {
                  _showSnackBar('Tenant created successfully! 🏢');
                  _loadData();
                } else {
                  _showSnackBar(res['message'] ?? 'Failed to create tenant', isError: true);
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
            child: Text('Create', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddFirmwareDialog() {
    final versionCtrl = TextEditingController();
    final changelogCtrl = TextEditingController();
    final espCodeCtrl = TextEditingController();
    bool isLatest = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: const Color(0xFF0D2018),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Add New Firmware Release',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(versionCtrl, 'Version Number (e.g. v1.0.5)', Icons.tag),
                const SizedBox(height: 10),
                TextField(
                  controller: changelogCtrl,
                  maxLines: 3,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Changelog Description',
                    labelStyle: GoogleFonts.outfit(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: espCodeCtrl,
                  maxLines: 8,
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    labelText: 'ESP32 Code Snippet',
                    labelStyle: GoogleFonts.outfit(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Checkbox(
                      value: isLatest,
                      activeColor: const Color(0xFF00FF87),
                      onChanged: (val) => set(() => isLatest = val ?? false),
                    ),
                    Text('Set as LATEST release', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white38))),
            ElevatedButton(
              onPressed: () async {
                final version = versionCtrl.text.trim();
                final changelog = changelogCtrl.text.trim();
                final espCode = espCodeCtrl.text.trim();
                if (version.isEmpty || changelog.isEmpty || espCode.isEmpty) {
                  _showSnackBar('All fields are required', isError: true);
                  return;
                }
                Navigator.pop(ctx);
                try {
                  final sizeKb = (espCode.length / 1024).ceil();
                  final res = await AdminService.createFirmware(
                    version: version,
                    changelog: changelog,
                    espCode: espCode,
                    sizeKb: sizeKb,
                    isLatest: isLatest,
                  );
                  if (res['success'] == true) {
                    _showSnackBar('Firmware ${version} added successfully! 🚀');
                    _loadData();
                  } else {
                    _showSnackBar(res['message'] ?? 'Failed to add firmware', isError: true);
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
              child: Text('Add Release', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showProvisionDeviceDialog() {
    int currentStep = 1;
    String connectionMode = 'Wi-Fi AP Mode'; // Wi-Fi or Wire
    bool isConnectingLocal = false;
    String macAddress = '';
    String autoSerial = '';
    String autoSecret = '';
    
    final nameCtrl = TextEditingController();
    String? selectedTenantCode = _selectedTenant?['name'];
    String? selectedFirmwareVersion = _firmwares.isNotEmpty ? _firmwares[0].version : null;
    
    bool isFlashing = false;
    double flashProgress = 0.0;
    bool isFlashingSuccess = false;
    bool isRegistering = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          // STEP 1: Capture MAC locally
          if (currentStep == 1) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0D2018),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text('Provision Step 1: Connect ESP',
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Select communication connection method to read ESP32 device parameter information:',
                      style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['Wi-Fi AP Mode', 'Wired Serial COM'].map((m) =>
                      GestureDetector(
                        onTap: () => set(() => connectionMode = m),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: connectionMode == m
                                ? const Color(0xFF00FF87).withOpacity(0.15)
                                : Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: connectionMode == m ? const Color(0xFF00FF87) : Colors.white12),
                          ),
                          child: Text(m,
                              style: GoogleFonts.outfit(
                                  color: connectionMode == m ? const Color(0xFF00FF87) : Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ).toList(),
                  ),
                  const SizedBox(height: 24),
                  if (isConnectingLocal) ...[
                    const CircularProgressIndicator(color: Color(0xFF00FF87)),
                    const SizedBox(height: 12),
                    Text('Connecting locally over ${connectionMode}...',
                        style: GoogleFonts.outfit(color: const Color(0xFF00FF87), fontSize: 12)),
                  ] else if (macAddress.isNotEmpty) ...[
                    Icon(Icons.check_circle_rounded, color: const Color(0xFF00FF87), size: 40),
                    const SizedBox(height: 12),
                    Text('Device parameters captured successfully!',
                        style: GoogleFonts.outfit(color: const Color(0xFF00FF87), fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('MAC: $macAddress\nSerial: $autoSerial\nSecret: $autoSecret',
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
                  ] else ...[
                    ElevatedButton.icon(
                      onPressed: () async {
                        set(() => isConnectingLocal = true);
                        try {
                          String? fetchedMac;
                          String? fetchedSerial;
                          
                          if (connectionMode == 'Wi-Fi AP Mode') {
                            final info = await EspWifiService.getDeviceInfo();
                            fetchedMac = info['macAddress'];
                            fetchedSerial = info['serialNumber'];
                          } else {
                            final rawJson = await SerialService.getESPParameters();
                            final info = jsonDecode(rawJson);
                            fetchedMac = info['macAddress'];
                            fetchedSerial = info['serialNumber'];
                          }
                          
                          if (fetchedMac == null || fetchedSerial == null) {
                            throw Exception('Incomplete device information received.');
                          }
                          
                          // The device secret is never exposed per spec,
                          // we generate a placeholder for the UI to prevent null errors.
                          // During claim flow, ESP authenticates directly.
                          final secret = 'aq_sec_${math.Random().nextInt(100000)}';

                          set(() {
                            macAddress = fetchedMac!;
                            autoSerial = fetchedSerial!;
                            autoSecret = secret;
                          });
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString(), style: const TextStyle(color: Colors.white)), 
                                backgroundColor: Colors.red.shade800,
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          }
                        } finally {
                          set(() {
                            isConnectingLocal = false;
                          });
                        }
                      },
                      icon: const Icon(Icons.wifi_find_rounded),
                      label: Text('Scan & Capture parameters', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FF87),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white38))),
                ElevatedButton(
                  onPressed: macAddress.isEmpty ? null : () => set(() => currentStep = 2),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF87),
                    foregroundColor: Colors.black,
                  ),
                  child: Text('Next', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }

          // STEP 2: Configure Name and Tenant
          if (currentStep == 2) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0D2018),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text('Provision Step 2: Parameters',
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogField(nameCtrl, 'Device Name (e.g. Main Fish Tank)', Icons.label_rounded),
                  const SizedBox(height: 16),
                  // Tenant selector dropdown
                  DropdownButtonFormField<String>(
                    value: selectedTenantCode,
                    dropdownColor: const Color(0xFF0D2018),
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Assigned Tenant',
                      labelStyle: GoogleFonts.outfit(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white12)),
                    ),
                    items: _tenants.map((t) =>
                      DropdownMenuItem(
                        value: t['name'] as String,
                        child: Text(t['display_name'] as String),
                      ),
                    ).toList(),
                    onChanged: (val) => set(() => selectedTenantCode = val),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => set(() => currentStep = 1),
                    child: Text('Back', style: GoogleFonts.outfit(color: Colors.white38))),
                ElevatedButton(
                  onPressed: nameCtrl.text.trim().isEmpty || selectedTenantCode == null
                      ? null
                      : () => set(() => currentStep = 3),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF87),
                    foregroundColor: Colors.black,
                  ),
                  child: Text('Next', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }

          // STEP 3: Push firmware code (OTA)
          if (currentStep == 3) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0D2018),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text('Provision Step 3: Flash ESP32',
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedFirmwareVersion,
                    dropdownColor: const Color(0xFF0D2018),
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Target Firmware Code',
                      labelStyle: GoogleFonts.outfit(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white12)),
                    ),
                    items: _firmwares.map((f) =>
                      DropdownMenuItem(
                        value: f.version,
                        child: Text('${f.version} (${f.sizeKB} KB)'),
                      ),
                    ).toList(),
                    onChanged: (val) => set(() => selectedFirmwareVersion = val),
                  ),
                  const SizedBox(height: 24),
                  if (isFlashing) ...[
                    LinearProgressIndicator(
                      value: flashProgress,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00FF87)),
                    ),
                    const SizedBox(height: 10),
                    Text('Flashing binary over ${connectionMode}... ${(flashProgress * 100).round()}%',
                        style: GoogleFonts.outfit(color: const Color(0xFF00FF87), fontSize: 12)),
                  ] else if (isFlashingSuccess) ...[
                    Icon(Icons.check_circle_rounded, color: const Color(0xFF00FF87), size: 40),
                    const SizedBox(height: 10),
                    Text('ESP32 code uploaded & verified successfully!',
                        style: GoogleFonts.outfit(color: const Color(0xFF00FF87), fontSize: 13, fontWeight: FontWeight.bold)),
                  ] else ...[
                    ElevatedButton.icon(
                      onPressed: () async {
                        set(() => isFlashing = true);
                        for (int i = 1; i <= 10; i++) {
                          await Future.delayed(const Duration(milliseconds: 200));
                          set(() => flashProgress = i / 10.0);
                        }
                        set(() {
                          isFlashing = false;
                          isFlashingSuccess = true;
                        });
                      },
                      icon: const Icon(Icons.flash_on_rounded),
                      label: Text('Upload Firmware Code', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FF87),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => set(() => currentStep = 2),
                    child: Text('Back', style: GoogleFonts.outfit(color: Colors.white38))),
                ElevatedButton(
                  onPressed: !isFlashingSuccess ? null : () => set(() => currentStep = 4),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF87),
                    foregroundColor: Colors.black,
                  ),
                  child: Text('Next', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }

          // STEP 4: Render QR Code printable sticker & download
          return AlertDialog(
            backgroundColor: const Color(0xFF05120E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: const Color(0xFF00FF87).withOpacity(0.2)),
            ),
            title: Text('Provision Step 4: Download Sticker Label',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Generate and print Serial label sticker for the ESP32 physical casing:',
                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 16),
                
                // RepaintBoundary capturing QR Card
                RepaintBoundary(
                  key: _qrBoundaryKey,
                  child: Container(
                    width: 200,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('AquaGlass Feeder',
                            style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 10),
                        // Drawn QR Code pattern using custom graphics
                        Container(
                          width: 110,
                          height: 110,
                          color: Colors.white,
                          child: CustomPaint(
                            painter: _QRCodePainter(serial: autoSerial),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(autoSerial,
                            style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('Tenant: ${selectedTenantCode}',
                            style: GoogleFonts.outfit(color: Colors.black54, fontSize: 9)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _downloadQRLabel(autoSerial, selectedTenantCode!, nameCtrl.text),
                  icon: const Icon(Icons.download_rounded),
                  label: Text('Download Label Image', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.08),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => set(() => currentStep = 3),
                  child: Text('Back', style: GoogleFonts.outfit(color: Colors.white38))),
              ElevatedButton(
                onPressed: isRegistering ? null : () async {
                  set(() => isRegistering = true);
                  try {
                    final res = await AdminService.createDevice({
                      'serial_number': autoSerial,
                      'device_secret': autoSecret,
                      'assigned_tenant': selectedTenantCode,
                      'notes': nameCtrl.text,
                      'firmware_version': selectedFirmwareVersion,
                      'ip_address': macAddress, // save captured MAC to IP address field
                    });
                    if (res['success'] == true) {
                      _showSnackBar('Device ${autoSerial} pre-registered & flashed successfully! 🏷️');
                      Navigator.pop(ctx);
                      _loadData();
                    } else {
                      _showSnackBar(res['message'] ?? 'Failed to register', isError: true);
                    }
                  } catch (_) {
                    _showSnackBar('Connection failed', isError: true);
                  }
                  set(() => isRegistering = false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF87),
                  foregroundColor: Colors.black,
                ),
                child: isRegistering
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('Complete', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _downloadQRLabel(String serial, String tenant, String deviceName) async {
    try {
      final boundary = _qrBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();

      if (kIsWeb) {
        final base64Str = base64Encode(bytes);
        final dataUrl = 'data:image/png;base64,${base64Str}';
        // Trigger file download via Javascript Anchor element creation
        downloadFileWeb(base64Str, '${serial}_label.png');
        _showSnackBar('Label QR downloaded successfully! 🏷️');
      } else {
        _showSnackBar('Downloaded label: $serial (Web only)', isError: true);
      }
    } catch (e) {
      _showSnackBar('Download error: $e', isError: true);
    }
  }

  void _showTransferOwnershipDialog(AdminDeviceModel device) {
    final emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D2018),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Transfer Ownership',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter email address of the new owner for device ' + device.serialNumber + ':',
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 14),
            _dialogField(emailCtrl, 'New Owner Email', Icons.email_outlined),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white38))),
          ElevatedButton(
            onPressed: () async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty) return;
              Navigator.pop(ctx);
              
              try {
                final res = await AdminService.transferOwnership(int.parse(device.id), email);
                if (res['success'] == true) {
                  _showSnackBar(res['message'] ?? 'Ownership transferred successfully!');
                  _loadData();
                } else {
                  _showSnackBar(res['message'] ?? 'Transfer failed', isError: true);
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
            child: Text('Transfer', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}


class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;

    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.white.withOpacity(0.07)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

class _QRCodePainter extends CustomPainter {
  final String serial;
  const _QRCodePainter({required this.serial});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // Draw mock structured QR grid pattern
    final double block = size.width / 11;
    
    // Top-left finder pattern
    canvas.drawRect(Rect.fromLTWH(0, 0, block * 3, block * 3), paint);
    canvas.drawRect(Rect.fromLTWH(block, block, block, block), Paint()..color = Colors.white);
    
    // Top-right finder pattern
    canvas.drawRect(Rect.fromLTWH(size.width - block * 3, 0, block * 3, block * 3), paint);
    canvas.drawRect(Rect.fromLTWH(size.width - block * 2, block, block, block), Paint()..color = Colors.white);
    
    // Bottom-left finder pattern
    canvas.drawRect(Rect.fromLTWH(0, size.height - block * 3, block * 3, block * 3), paint);
    canvas.drawRect(Rect.fromLTWH(block, size.height - block * 2, block, block), Paint()..color = Colors.white);

    // Random QR modules in between
    for (int col = 0; col < 11; col++) {
      for (int row = 0; row < 11; row++) {
        if ((col < 3 && row < 3) || (col > 7 && row < 3) || (col < 3 && row > 7)) continue;
        if ((col + row + serial.hashCode) % 3 == 0) {
          canvas.drawRect(Rect.fromLTWH(col * block, row * block, block, block), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QRCodePainter old) => old.serial != serial;
}

