import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:appecommerce/core/network/api_client.dart';

void main() {
  test('dbg', () async {
    final f = File('${Directory.systemTemp.path}/dbg.jpg')..writeAsBytesSync([1,2,3]);
    final client = MockClient((r) async => http.Response(jsonEncode({'errors': {'foto': ['La foto pesa mucho']}}), 422));
    final raw = await http.Response.fromStream(await client.send(http.MultipartRequest('POST', Uri.parse('http://x/y'))..files.add(await http.MultipartFile.fromPath('foto', f.path))));
    print('STATUS ${raw.statusCode} BODY [${raw.body}] len=${raw.bodyBytes.length}');
    final r2 = await client.post(Uri.parse('http://x/y'));
    print('POST BODY [${r2.body}]');
  });
}
