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
  final String? error;

  bool get hasOnvifInfo =>
      manufacturer != null || model != null || serialNumber != null;

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
        'error',
      ];
}
