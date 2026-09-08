class ConnectedClient {
  final String id;
  final String deviceName;
  String currentStation;
  final DateTime connectedAt;

  ConnectedClient({
    required this.id,
    required this.deviceName,
    required this.currentStation,
    required this.connectedAt,
  });
}
