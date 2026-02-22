import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:frontend/src/grpc_client.dart';
import 'package:frontend/src/generated/tempconv.pb.dart';
import 'package:frontend/src/generated/tempconv.pbgrpc.dart';

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  final _celsiusController = TextEditingController();
  final _fahrenheitController = TextEditingController();
  String _statusMessage = '';
  bool _isLoading = false;
  TemperatureConverterClient? _client;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _client = createGrpcClient();
    }
  }

  @override
  void dispose() {
    _celsiusController.dispose();
    _fahrenheitController.dispose();
    super.dispose();
  }

  Future<void> _convertCelsiusToFahrenheit() async {
    if (_client == null) {
      setState(() => _statusMessage = 'gRPC-Web not available on this platform');
      return;
    }

    final text = _celsiusController.text.trim();
    if (text.isEmpty) {
      setState(() => _statusMessage = 'Enter a value in Celsius');
      return;
    }

    final celsius = double.tryParse(text);
    if (celsius == null) {
      setState(() => _statusMessage = 'Invalid number');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '';
      _fahrenheitController.clear();
    });

    try {
      final response = await _client!.celsiusToFahrenheit(
        CelsiusRequest()..celsius = celsius,
      );
      setState(() {
        _fahrenheitController.text = response.fahrenheit.toStringAsFixed(2);
        _statusMessage = '✓ ${celsius}°C = ${response.fahrenheit.toStringAsFixed(2)}°F';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _convertFahrenheitToCelsius() async {
    if (_client == null) {
      setState(() => _statusMessage = 'gRPC-Web not available on this platform');
      return;
    }

    final text = _fahrenheitController.text.trim();
    if (text.isEmpty) {
      setState(() => _statusMessage = 'Enter a value in Fahrenheit');
      return;
    }

    final fahrenheit = double.tryParse(text);
    if (fahrenheit == null) {
      setState(() => _statusMessage = 'Invalid number');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '';
      _celsiusController.clear();
    });

    try {
      final response = await _client!.fahrenheitToCelsius(
        FahrenheitRequest()..fahrenheit = fahrenheit,
      );
      setState(() {
        _celsiusController.text = response.celsius.toStringAsFixed(2);
        _statusMessage = '✓ ${fahrenheit}°F = ${response.celsius.toStringAsFixed(2)}°C';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Temperature Converter'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.thermostat, size: 64, color: Color(0xFF1565C0)),
                const SizedBox(height: 24),
                const Text(
                  'Convert between Celsius and Fahrenheit via gRPC-Web',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _celsiusController,
                  decoration: const InputDecoration(
                    labelText: 'Celsius (°C)',
                    border: OutlineInputBorder(),
                    hintText: 'e.g. 100',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onSubmitted: (_) => _convertCelsiusToFahrenheit(),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _convertCelsiusToFahrenheit,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_downward),
                  label: const Text('Convert to Fahrenheit'),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _fahrenheitController,
                  decoration: const InputDecoration(
                    labelText: 'Fahrenheit (°F)',
                    border: OutlineInputBorder(),
                    hintText: 'e.g. 212',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onSubmitted: (_) => _convertFahrenheitToCelsius(),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _convertFahrenheitToCelsius,
                  icon: const Icon(Icons.arrow_upward),
                  label: const Text('Convert to Celsius'),
                ),
                const SizedBox(height: 24),
                if (_statusMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _statusMessage.startsWith('Error')
                          ? Colors.red.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _statusMessage,
                      style: TextStyle(
                        color: _statusMessage.startsWith('Error')
                            ? Colors.red.shade900
                            : Colors.green.shade900,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
