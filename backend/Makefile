# Generate Go code from proto files.
# Uses the proto/ directory at repo root.
PROTO_DIR = ../proto

.PHONY: generate
generate:
	protoc -I $(PROTO_DIR) --go_out=. --go_opt=module=tempconv/grpc \
		--go-grpc_out=. --go-grpc_opt=module=tempconv/grpc \
		$(PROTO_DIR)/tempconv.proto
