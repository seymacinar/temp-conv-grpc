package server

import (
	"context"

	"tempconv/grpc/proto"
)

// TemperatureConverterServer implements the TemperatureConverter gRPC service.
type TemperatureConverterServer struct {
	proto.UnimplementedTemperatureConverterServer
}

// NewTemperatureConverterServer creates a new TemperatureConverterServer.
func NewTemperatureConverterServer() *TemperatureConverterServer {
	return &TemperatureConverterServer{}
}

// CelsiusToFahrenheit converts degrees Celsius to Fahrenheit.
// Formula: F = C * 9/5 + 32
func (s *TemperatureConverterServer) CelsiusToFahrenheit(
	ctx context.Context,
	req *proto.CelsiusRequest,
) (*proto.FahrenheitResponse, error) {
	fahrenheit := req.Celsius*9/5 + 32
	return &proto.FahrenheitResponse{Fahrenheit: fahrenheit}, nil
}

// FahrenheitToCelsius converts degrees Fahrenheit to Celsius.
// Formula: C = (F - 32) * 5/9
func (s *TemperatureConverterServer) FahrenheitToCelsius(
	ctx context.Context,
	req *proto.FahrenheitRequest,
) (*proto.CelsiusResponse, error) {
	celsius := (req.Fahrenheit - 32) * 5 / 9
	return &proto.CelsiusResponse{Celsius: celsius}, nil
}
