package main

import (
	"fmt"
	"log"
	"net"

	"tempconv/grpc/proto"
	"tempconv/grpc/server"

	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"
)

func main() {
	port := 50051
	lis, err := net.Listen("tcp", fmt.Sprintf(":%d", port))
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	s := grpc.NewServer()
	proto.RegisterTemperatureConverterServer(s, server.NewTemperatureConverterServer())
	reflection.Register(s)

	log.Printf("gRPC server listening on port %d", port)
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
