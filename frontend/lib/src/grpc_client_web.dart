import 'dart:html' as html;

import 'package:grpc/grpc_web.dart';
import 'package:frontend/src/generated/tempconv.pbgrpc.dart';

TemperatureConverterClient createGrpcClient() {
  final baseUrl = html.window.location.origin;
  final channel = GrpcWebClientChannel.xhr(Uri.parse(baseUrl));
  return TemperatureConverterClient(channel);
}
