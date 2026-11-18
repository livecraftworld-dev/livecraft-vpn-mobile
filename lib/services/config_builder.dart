import 'dart:convert';
import '../models/server_config.dart';

class ConfigBuilder {
  static const List<String> russianDomains = [
    "ru", "рф", "xn--p1ai", "su", "moscow", "tatar", "psk", "yandex",
    "xn--80adxhks", "xn--80asehdb", "xn--80aswg", "xn--c1avg", "xn--d1acj3b", "xn--p1acf",
    "24h.tv", "5post.market", "aviasales.com", "avito.st", "avs.io", "boosty.to",
    "chizhik.club", "dbo-dengi.online", "dodois.com", "dodois.io", "dodopizza.com",
    "dodostatic.net", "donationalerts.com", "emias.info", "evrasia.rest", "fix-price.com",
    "kinopoisk-ru.clstorage.net", "kinorium.com", "lenta.com", "lenta.tech", "memealerts.com",
    "moex.com", "mosmetro.tech", "mradx.net", "mvk.com", "mycdn.me", "naydex.net",
    "netmonet.co", "ngenix.net", "okko.sport", "okko.tv", "okolo.app", "ozonusercontent.com",
    "paywb.com", "perekrestok.com", "premier.one", "restream-media.net", "rostaxi.org",
    "ru.com", "ru.net", "sberbank.com", "sistema-capital.com", "smotreshka.tv", "t1.cloud",
    "tamtam.chat", "taxsee.com", "tbank-online.com", "tips.tips", "tochka-tech.com",
    "tochka.com", "trbcdn.net", "turbopages.org", "uni.rest", "unirest.tech", "userapi.com",
    "vk-apps.com", "vk-cdn.me", "vk-cdn.net", "vk-portal.net", "vk.cc", "vk.com",
    "vk.company", "vk.design", "vk.link", "vk.me", "vk.team", "vkcache.com", "vkgo.app",
    "vklive.app", "vkmessenger.app", "vkmessenger.com", "vkuser.net", "vkuseraudio.com",
    "vkuseraudio.net", "vkuserlive.net", "vkuservideo.com", "vkuservideo.net", "webvisor.com",
    "webvisor.org", "x5.ai", "x5.com", "x5.digital", "x5.group", "x5.media", "x5.team",
    "x5.tech", "x5static.net", "yads.tech", "yandex-bank.net", "yandex-images.clstorage.net",
    "yandex.aero", "yandex.az", "yandex.by", "yandex.cloud", "yandex.co.il", "yandex.com",
    "yandex.com.am", "yandex.com.ge", "yandex.com.tr", "yandex.com.ua", "yandex.de",
    "yandex.ee", "yandex.eu", "yandex.fi", "yandex.fr", "yandex.jobs", "yandex.kg",
    "yandex.kz", "yandex.lt", "yandex.lv", "yandex.md", "yandex.net", "yandex.org",
    "yandex.pl", "yandex.st", "yandex.sx", "yandex.tj", "yandex.tm", "yandex.tr",
    "yandex.ua", "yandex.uz", "yandexadexchange.net", "yandexcloud.net", "yandexcom.net",
    "yandexmetrica.com", "yandexwebcache.org", "yastat.net", "yastatic.net", "yclients.com",
    "dzen.ru", "ya.ru", "yandex.ru", "mail.ru", "my.games", "gosuslugi.ru", "sberbank.ru",
    "tbank.ru", "tinkoff.ru", "vtb.ru", "cbr.ru", "nalog.ru", "mos.ru"
  ];

  static String buildJson(
    ServerConfig server, {
    bool bypassRussian = true,
    List<String> excludedPackages = const [],
  }) {
    final rules = <Map<String, dynamic>>[
      {"action": "sniff"},
      {"protocol": "dns", "action": "hijack-dns"},
      {"ip_is_private": true, "outbound": "direct"},
      {"ip_cidr": ["77.88.8.8/32"], "outbound": "direct"}
    ];

    if (excludedPackages.isNotEmpty) {
      rules.add({
        "package_name": excludedPackages,
        "outbound": "direct",
      });
    }

    final dnsRules = <Map<String, dynamic>>[];

    if (bypassRussian) {
      rules.add({
        "domain_suffix": russianDomains,
        "outbound": "direct"
      });
      rules.add({
        "domain": ["yandex-pogoda.static-storage.net"],
        "outbound": "direct"
      });

      dnsRules.add({
        "domain_suffix": russianDomains,
        "server": "dns-direct"
      });
      dnsRules.add({
        "domain": ["yandex-pogoda.static-storage.net"],
        "server": "dns-direct"
      });
    }

    final config = {
      "log": {"level": "warn"},
      "dns": {
        "servers": [
          {
            "tag": "dns-remote",
            "type": "udp",
            "server": "1.1.1.1",
            "server_port": 53,
            "detour": "proxy"
          },
          {
            "tag": "dns-direct",
            "type": "udp",
            "server": "77.88.8.8",
            "server_port": 53
          }
        ],
        "rules": dnsRules,
        "strategy": "ipv4_only"
      },
      "inbounds": [
        {
          "type": "tun",
          "tag": "tun-in",
          "interface_name": "tun0",
          "address": ["172.28.0.1/30"],
          "auto_route": true,
          "strict_route": false,
          "stack": "mixed"
        }
      ],
      "outbounds": [
        {
          "type": "vless",
          "tag": "proxy",
          "server": server.ip,
          "server_port": server.port,
          "uuid": server.uuid,
          "flow": "xtls-rprx-vision",
          "tls": {
            "enabled": true,
            "server_name": server.sni,
            "utls": {"enabled": true, "fingerprint": "chrome"},
            "reality": {
              "enabled": true,
              "public_key": server.pubKey,
              "short_id": server.shortId
            }
          }
        },
        {"type": "direct", "tag": "direct"}
      ],
      "route": {
        "default_domain_resolver": "dns-remote",
        "auto_detect_interface": true,
        "rules": rules,
        "final": "proxy"
      }
    };

    return jsonEncode(config);
  }
}
