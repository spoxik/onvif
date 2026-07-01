class DeviceResult {
  const DeviceResult({
    required this.ip,
    required this.port,
    this.protocol = 'TCP',
    this.manufacturer,
    this.model,
    this.firmwareVersion,
    this.serialNumber,
    this.hardwareId,
    this.source = 'LAN',
    this.country,
    this.organization,
    this.hostnames = const [],
    this.latitude,
    this.longitude,
    this.favorite = false,
    this.labels = const [],
    this.note,
    this.rtspUrl,
    this.rtspOk,
    this.authProfileName,
    this.error,
  });

  final String ip;
  final int port;
  final String protocol;
  final String? manufacturer;
  final String? model;
  final String? firmwareVersion;
  final String? serialNumber;
  final String? hardwareId;
  final String source;
  final String? country;
  final String? organization;
  final List<String> hostnames;
  final double? latitude;
  final double? longitude;
  final bool favorite;
  final List<String> labels;
  final String? note;
  final String? rtspUrl;
  final bool? rtspOk;
  final String? authProfileName;
  final String? error;

  String get id => '$source|$ip|$port|${serialNumber ?? ''}';

  bool get hasOnvifInfo =>
      manufacturer != null || model != null || serialNumber != null;

  bool get hasLocation => latitude != null && longitude != null;

  DeviceResult copyWith({
    String? ip,
    int? port,
    String? protocol,
    String? manufacturer,
    String? model,
    String? firmwareVersion,
    String? serialNumber,
    String? hardwareId,
    String? source,
    String? country,
    String? organization,
    List<String>? hostnames,
    double? latitude,
    double? longitude,
    bool? favorite,
    List<String>? labels,
    String? note,
    String? rtspUrl,
    bool? rtspOk,
    String? authProfileName,
    String? error,
  }) {
    return DeviceResult(
      ip: ip ?? this.ip,
      port: port ?? this.port,
      protocol: protocol ?? this.protocol,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      serialNumber: serialNumber ?? this.serialNumber,
      hardwareId: hardwareId ?? this.hardwareId,
      source: source ?? this.source,
      country: country ?? this.country,
      organization: organization ?? this.organization,
      hostnames: hostnames ?? this.hostnames,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      favorite: favorite ?? this.favorite,
      labels: labels ?? this.labels,
      note: note ?? this.note,
      rtspUrl: rtspUrl ?? this.rtspUrl,
      rtspOk: rtspOk ?? this.rtspOk,
      authProfileName: authProfileName ?? this.authProfileName,
      error: error ?? this.error,
    );
  }

  Map<String, dynamic> toJson() => {
        'ip': ip,
        'port': port,
        'protocol': protocol,
        'manufacturer': manufacturer,
        'model': model,
        'firmwareVersion': firmwareVersion,
        'serialNumber': serialNumber,
        'hardwareId': hardwareId,
        'source': source,
        'country': country,
        'organization': organization,
        'hostnames': hostnames,
        'latitude': latitude,
        'longitude': longitude,
        'favorite': favorite,
        'labels': labels,
        'note': note,
        'rtspUrl': rtspUrl,
        'rtspOk': rtspOk,
        'authProfileName': authProfileName,
        'error': error,
      };

  factory DeviceResult.fromJson(Map<String, dynamic> json) {
    return DeviceResult(
      ip: json['ip']?.toString() ?? '',
      port: int.tryParse(json['port']?.toString() ?? '') ?? 0,
      protocol: json['protocol']?.toString() ?? 'TCP',
      manufacturer: json['manufacturer']?.toString(),
      model: json['model']?.toString(),
      firmwareVersion: json['firmwareVersion']?.toString(),
      serialNumber: json['serialNumber']?.toString(),
      hardwareId: json['hardwareId']?.toString(),
      source: json['source']?.toString() ?? 'LAN',
      country: json['country']?.toString(),
      organization: json['organization']?.toString(),
      hostnames: (json['hostnames'] as List? ?? const []).map((e) => e.toString()).toList(),
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
      favorite: json['favorite'] == true,
      labels: (json['labels'] as List? ?? const []).map((e) => e.toString()).toList(),
      note: json['note']?.toString(),
      rtspUrl: json['rtspUrl']?.toString(),
      rtspOk: json['rtspOk'] is bool ? json['rtspOk'] as bool : null,
      authProfileName: json['authProfileName']?.toString(),
      error: json['error']?.toString(),
    );
  }

  List<String> toCsvRow() => [
        source,
        ip,
        port.toString(),
        protocol,
        manufacturer ?? '',
        model ?? '',
        firmwareVersion ?? '',
        serialNumber ?? '',
        hardwareId ?? '',
        country ?? '',
        organization ?? '',
        hostnames.join(' | '),
        latitude?.toString() ?? '',
        longitude?.toString() ?? '',
        favorite ? 'TAK' : 'NIE',
        labels.join(' | '),
        note ?? '',
        rtspUrl ?? '',
        rtspOk == null ? '' : (rtspOk! ? 'OK' : 'NIE'),
        authProfileName ?? '',
        error ?? '',
      ];

  static List<String> get csvHeader => [
        'source',
        'ip',
        'port',
        'protocol',
        'manufacturer',
        'model',
        'firmwareVersion',
        'serialNumber',
        'hardwareId',
        'country',
        'organization',
        'hostnames',
        'latitude',
        'longitude',
        'favorite',
        'labels',
        'note',
        'rtspUrl',
        'rtspStatus',
        'authProfileName',
        'error',
      ];
}
