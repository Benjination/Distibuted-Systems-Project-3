#!/usr/bin/env python3
"""
Raft Test Client - Demonstrates Raft log replication and database updates
"""
import grpc
import sys
import os
import time

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../proto'))
import raft_pb2
import raft_pb2_grpc

def test_raft_update(host="localhost", port="50054", drug_id=1, new_quantity=777):
    """
    Send a ClientCommand to the Raft cluster to update a drug's quantity.
    The command will be replicated across all nodes via Raft consensus.
    """
    channel = grpc.insecure_channel(f"{host}:{port}")
    stub = raft_pb2_grpc.RaftStub(channel)

    print("=" * 70)
    print("🗳️  Raft Consensus Test - Database Update via Log Replication")
    print("=" * 70)
    
    # Format: "UPDATE:drug_id:new_quantity"
    command = f"UPDATE:{drug_id}:{new_quantity}"
    
    print(f"\n📝 Sending command to Raft cluster: {command}")
    print(f"   Target: {host}:{port}")
    print(f"   Drug ID: {drug_id}")
    print(f"   New Quantity: {new_quantity}")
    print("\n⏳ Waiting for Raft consensus...")
    
    try:
        response = stub.ClientCommand(
            raft_pb2.ClientRequest(command=command),
            timeout=10.0
        )
        
        print("\n" + "=" * 70)
        if response.success:
            print("✅ SUCCESS - Raft consensus achieved!")
            print(f"   Message: {response.message}")
            print("\n📊 What happened:")
            print("   1. Leader received the command")
            print("   2. Leader appended to its log")
            print("   3. Leader replicated to followers via AppendEntries RPC")
            print("   4. Majority acknowledged (consensus reached)")
            print("   5. Leader committed the entry")
            print("   6. All nodes applied the UPDATE to the database")
        else:
            print("❌ FAILED - Raft consensus not reached")
            print(f"   Message: {response.message}")
            print("\n⚠️  Possible reasons:")
            print("   - No leader elected yet (election in progress)")
            print("   - Leader unreachable or crashed")
            print("   - Majority of nodes are down")
        print("=" * 70)
        
        return response.success
        
    except grpc.RpcError as e:
        print(f"\n❌ RPC Error: {e.code()}")
        print(f"   Details: {e.details()}")
        print("\n⚠️  This could mean:")
        print("   - The node you connected to is not the leader")
        print("   - No leader has been elected yet")
        print("   - The Raft service is not running")
        return False

def main():
    host = sys.argv[1] if len(sys.argv) > 1 else "localhost"
    port = sys.argv[2] if len(sys.argv) > 2 else "50054"
    drug_id = int(sys.argv[3]) if len(sys.argv) > 3 else 1
    new_quantity = int(sys.argv[4]) if len(sys.argv) > 4 else 777
    
    print("\n🔍 Testing Raft consensus and database replication...")
    print(f"   Connecting to any node on port {port}")
    print(f"   (If not leader, will forward to leader automatically)\n")
    
    time.sleep(2)  # Give leader election time to complete
    
    success = test_raft_update(host, port, drug_id, new_quantity)
    
    if success:
        print("\n📌 Next steps to verify:")
        print("   1. Check the logs: docker logs node2-api-server-a")
        print("   2. Query the database:")
        print(f"      docker exec -it node4-db-primary psql -U postgres -d pharmacy \\")
        print(f"        -c \"SELECT id, name, quantity FROM drugs WHERE id={drug_id};\"")
        print(f"   3. You should see quantity = {new_quantity}")
    
    print()

if __name__ == "__main__":
    main()
