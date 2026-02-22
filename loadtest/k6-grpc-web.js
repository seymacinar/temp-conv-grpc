/**
 * k6 load test for Temperature Converter gRPC API
 *
 * Simulates many concurrent clients calling the backend.
 * Uses k6's native gRPC to hit the backend directly (port 50051).
 * This exercises the same conversion logic that frontend clients
 * trigger via gRPC-Web -> Envoy -> backend.
 *
 * Run (with backend exposed):
 *   k6 run loadtest/k6-grpc-web.js
 *
 * For full stack test, expose backend or run inside cluster.
 */
import grpc from 'k6/net/grpc';
import { check, sleep } from 'k6';

const BACKEND_URL = __ENV.BACKEND_URL || '127.0.0.1:50051';

const client = new grpc.Client();
client.load([], 'proto/tempconv.proto');

export const options = {
  stages: [
    { duration: '30s', target: 20 },
    { duration: '1m', target: 50 },
    { duration: '30s', target: 100 },
    { duration: '1m', target: 100 },
    { duration: '30s', target: 0 },
  ],
  // thresholds optional - k6 grpc metrics may vary by version
  thresholds: {
    checks: ['rate>0.95'],
  },
};

export default function () {
  client.connect(BACKEND_URL, { plaintext: true });

  const celsius = Math.random() * 100;
  const response = client.invoke('tempconv.TemperatureConverter/CelsiusToFahrenheit', {
    celsius: celsius,
  });

  check(response, {
    'status is OK': (r) => r && r.status === grpc.StatusOK,
    'has fahrenheit': (r) => r && r.message && typeof r.message.fahrenheit === 'number',
  });

  client.close();
  sleep(0.5);
}
