class ServerConfig {
  final String id;
  final String name;
  final String flag;
  final String city;
  final String ip;
  final int port;
  final String uuid;
  final String shortId;
  final String pubKey;
  final String sni;
  final String ping;
  final String description;

  const ServerConfig({
    required this.id,
    required this.name,
    required this.flag,
    required this.city,
    required this.ip,
    required this.port,
    required this.uuid,
    required this.shortId,
    required this.pubKey,
    required this.sni,
    required this.ping,
    required this.description,
  });

  static const List<ServerConfig> availableServers = [
    ServerConfig(
      id: 'amsterdam',
      name: 'Нидерланды',
      flag: '🇳🇱',
      city: 'Амстердам',
      ip: '144.124.246.32',
      port: 443,
      uuid: '104e8ecf-a413-4985-a4d5-90d9196e37aa',
      shortId: '7e04f16df48b57c6',
      pubKey: 'hEQ9jUEa8r7Jq-U8RZIvcpBw1wvCrCwEZig-epMglHQ',
      sni: 'www.samsung.com',
      ping: '35 ms',
      description: 'Без цензуры • Полная скорость • YouTube',
    ),
    ServerConfig(
      id: 'moscow',
      name: 'Россия',
      flag: '🇷🇺',
      city: 'Москва',
      ip: '194.58.70.192',
      port: 443,
      uuid: '68165232-3968-474a-9ed9-ee2bcaccc18d',
      shortId: '7e04f16df48b57c6',
      pubKey: 'AxD7UYCSYzOSiXRykpbsW5LGbTLaeACthBfLZMxN0jU',
      sni: 'www.samsung.com',
      ping: '8 ms',
      description: 'Москва • Хаб РФ • Защищенный корпоративный канал',
    ),
  ];
}
