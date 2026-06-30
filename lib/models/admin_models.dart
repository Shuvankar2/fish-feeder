class AdminUserModel {
  final String id;
  String name;
  final String email;
  final String phone;
  String status; // 'Active', 'Suspended'
  final DateTime joinDate;
  List<String> deviceIds;
  final String role; // 'Owner', 'Editor', 'Viewer'

  AdminUserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.status,
    required this.joinDate,
    required this.deviceIds,
    required this.role,
  });
}

class DeviceMemberModel {
  final String id;
  final String name;
  final String email;
  String role; // 'Owner', 'Editor', 'Viewer'
  final DateTime joinedAt;

  DeviceMemberModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.joinedAt,
  });
}

class AdminDeviceModel {
  final String id;
  String name;
  final String serialNumber;
  final String macAddress;
  String firmware;
  bool isOnline;
  final String ownerEmail;
  int feedsToday;
  int failedFeeds;
  final String location;
  int? foodLevelPercent;
  DateTime lastSeen;
  String status;
  List<DeviceMemberModel> members;

  AdminDeviceModel({
    required this.id,
    required this.name,
    required this.serialNumber,
    required this.macAddress,
    required this.firmware,
    required this.isOnline,
    required this.ownerEmail,
    required this.feedsToday,
    required this.failedFeeds,
    required this.location,
    this.foodLevelPercent,
    required this.lastSeen,
    required this.status,
    required this.members,
  });
}

class FeedLogModel {
  final String id;
  final String deviceId;
  final String deviceName;
  final String type; // 'Auto', 'Manual', 'Vacation-Skip'
  final DateTime timestamp;
  final String status; // 'Success', 'Failed'
  final String portionSize;

  FeedLogModel({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.type,
    required this.timestamp,
    required this.status,
    required this.portionSize,
  });
}

class FirmwareModel {
  final String version;
  final DateTime releaseDate;
  final String changelog;
  final String sizeKB;
  final bool isLatest;

  FirmwareModel({
    required this.version,
    required this.releaseDate,
    required this.changelog,
    required this.sizeKB,
    required this.isLatest,
  });
}
