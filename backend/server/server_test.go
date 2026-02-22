package server

import (
	"context"
	"testing"

	"tempconv/grpc/proto"
)

func TestCelsiusToFahrenheit(t *testing.T) {
	srv := NewTemperatureConverterServer()
	ctx := context.Background()

	tests := []struct {
		celsius    float64
		fahrenheit float64
	}{
		{0, 32},
		{100, 212},
		{-40, -40},
		{37, 98.6},
	}

	for _, tt := range tests {
		resp, err := srv.CelsiusToFahrenheit(ctx, &proto.CelsiusRequest{Celsius: tt.celsius})
		if err != nil {
			t.Fatalf("CelsiusToFahrenheit(%v) error: %v", tt.celsius, err)
		}
		// Allow small floating-point tolerance
		diff := resp.Fahrenheit - tt.fahrenheit
		if diff < -0.01 || diff > 0.01 {
			t.Errorf("CelsiusToFahrenheit(%v) = %v, want %v", tt.celsius, resp.Fahrenheit, tt.fahrenheit)
		}
	}
}

func TestFahrenheitToCelsius(t *testing.T) {
	srv := NewTemperatureConverterServer()
	ctx := context.Background()

	tests := []struct {
		fahrenheit float64
		celsius    float64
	}{
		{32, 0},
		{212, 100},
		{-40, -40},
		{98.6, 37},
	}

	for _, tt := range tests {
		resp, err := srv.FahrenheitToCelsius(ctx, &proto.FahrenheitRequest{Fahrenheit: tt.fahrenheit})
		if err != nil {
			t.Fatalf("FahrenheitToCelsius(%v) error: %v", tt.fahrenheit, err)
		}
		diff := resp.Celsius - tt.celsius
		if diff < -0.01 || diff > 0.01 {
			t.Errorf("FahrenheitToCelsius(%v) = %v, want %v", tt.fahrenheit, resp.Celsius, tt.celsius)
		}
	}
}
