import 'dart:convert';
import 'dart:io';

import 'package:yeedart/src/domain/entity/yee_device.dart';
import 'package:yeedart/src/data/parser.dart';
import 'package:yeedart/src/domain/entity/yee_discovery_response.dart';

class Yeelight {
  static const _address = "239.255.255.250";
  static const _port = 1982;

  /// Sends search message to discover Yeelight devices.
  ///
  ///
  /// Message should follow this format:
  /// ```
  /// M-SEARCH * HTTP/1.1
  /// HOST: 239.255.255.250:1982
  /// MAN: "ssdp:discover"
  /// ST: wifi_bulb
  /// ```
  /// * First line must be `M-SEARCH * HTTP/1.1`.
  /// * "HOST" header is optional. If present, the value should be
  /// `239.255.255.250:1982`.
  /// * "MAN" header is *required* and value must be `"ssdp:discover"`
  /// (with double quotes).
  /// * "ST" header is required and value must be `wifi_bulb`.
  /// * Headers are case-insensitive, start line and all the header values are
  /// case sensitive.
  /// * Each line should be terminated by `\r\n`.
  ///
  /// Any messages that doesn't follow these rules will be silently dropped.
  static Future<List<YeeDevice>> dicoverDevices({
    Duration timeout = const Duration(seconds: 2),
    String address = _address,
    int port = _port,
    RawDatagramSocket socket,
  }) async {
    final internetAddress = InternetAddress(address);
    final message = "M-SEARCH * HTTP/1.1\r\n"
        "HOST: ${internetAddress.address}:$port\r\n"
        "MAN: \"ssdp:discover\"\r\n"
        "ST: wifi_bulb\r\n";

    final devices = <YeeDevice>[];

    final udpSocket =
        socket ?? await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
    final udpSocketEventStream = udpSocket.timeout(
      timeout,
      onTimeout: (e) => udpSocket.close(),
    );

    // send discovery message
    udpSocket.send(utf8.encode(message), internetAddress, port);

    await for (final event in udpSocketEventStream) {
      if (event == RawSocketEvent.read) {
        final datagram = udpSocket.receive();
        if (datagram != null && datagram.data.isNotEmpty) {
          //print(utf8.decode(datagram.data));
          final map = Parser.parseDiscoveryResponse(utf8.decode(datagram.data));
          final response = YeeDiscoveryResponse.fromMap(map);
          final device = YeeDevice.fromResponse(response);

          if (!devices.contains(device)) {
            devices.add(device);
          }
        }
      }
    }

    return devices;
  }
}