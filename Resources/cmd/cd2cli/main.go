package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"time"

	pb "cd2cli/clouddrive"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/metadata"
)

func main() {
	action := flag.String("action", "", "Action: mount or unmount")
	mountPoint := flag.String("mountpoint", "", "Mount point path")
	token := flag.String("token", "", "API token")
	server := flag.String("server", "localhost:19798", "gRPC server address")
	flag.Parse()

	if *action == "" || *mountPoint == "" {
		fmt.Println("Usage: cd2cli -action mount|unmount -mountpoint <path> -token <api-token>")
		os.Exit(1)
	}

	conn, err := grpc.Dial(*server, grpc.WithTransportCredentials(insecure.NewCredentials()), grpc.WithBlock())
	if err != nil {
		log.Fatalf("did not connect: %v", err)
	}
	defer conn.Close()

	client := pb.NewCloudDriveFileSrvClient(conn)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if *token != "" {
		ctx = metadata.AppendToOutgoingContext(ctx, "authorization", "Bearer "+*token)
	}

	req := &pb.MountPointRequest{MountPoint: *mountPoint}

	var result *pb.MountPointResult
	var err2 error

	switch *action {
	case "mount":
		result, err2 = client.Mount(ctx, req)
	case "unmount":
		result, err2 = client.Unmount(ctx, req)
	default:
		fmt.Printf("Unknown action: %s\n", *action)
		os.Exit(1)
	}

	if err2 != nil {
		log.Fatalf("RPC failed: %v", err2)
	}

	if result.Success {
		fmt.Printf("Success: %s %s\n", *action, *mountPoint)
	} else {
		fmt.Printf("Failed: %s\n", result.FailReason)
		os.Exit(1)
	}
}
