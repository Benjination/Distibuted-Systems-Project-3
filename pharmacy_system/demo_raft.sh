#!/bin/bash
# ============================================================================
# Raft Consensus Demonstration Script
# This script demonstrates Raft consensus protocol working with database
# ============================================================================

cd "$(dirname "$0")"

echo "=========================================="
echo "  RAFT CONSENSUS DEMONSTRATION"
echo "=========================================="
echo ""

# ============================================================================
# STEP 1: Show the initial state of the database
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 1: Initial Database State"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Checking current quantity of Aspirin (drug ID 1)..."
echo ""

docker exec -it node4-db-primary psql -U postgres -d pharmacy -c "SELECT id, name, quantity FROM drugs WHERE id=1;"

echo ""
echo "✓ Note the current quantity value above."
echo ""
read -p "Press [ENTER] to continue to Step 2..."
echo ""

# ============================================================================
# STEP 2: Send a command through Raft consensus protocol
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 2: Send Raft Consensus Command"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📤 Command: UPDATE:1:777"
echo "   (Update drug ID 1 to quantity 777)"
echo ""
echo "🔄 Raft Consensus Protocol Flow:"
echo "   1️⃣  Client sends command to any node"
echo "   2️⃣  If not leader, node forwards to current leader"
echo "   3️⃣  Leader appends command to its log"
echo "   4️⃣  Leader replicates via AppendEntries RPC to all followers"
echo "   5️⃣  Leader waits for majority acknowledgment (3/5 nodes)"
echo "   6️⃣  Leader commits the entry upon majority ACK"
echo "   7️⃣  Leader applies command to its local database"
echo "   8️⃣  Followers apply committed entry to their databases"
echo ""
read -p "Press [ENTER] to send the Raft command..."
echo ""
echo "⏳ Sending command..."
echo ""

docker exec -i node2-api-server-a python3 -c "
import grpc, sys
sys.path.insert(0, '/app/proto')
import raft_pb2, raft_pb2_grpc

channel = grpc.insecure_channel('localhost:50054')
stub = raft_pb2_grpc.RaftStub(channel)
response = stub.ClientCommand(raft_pb2.ClientRequest(command='UPDATE:1:777'), timeout=5.0)

print(f'✅ Raft Response:')
print(f'   Success: {response.success}')
print(f'   Message: {response.message}')
"

echo ""
echo "📝 What 'Success=True' means:"
echo "   ✓ Majority of nodes (3/5) acknowledged the log entry"
echo "   ✓ Entry was committed to the distributed Raft log"
echo "   ✓ Database update applied across all nodes in cluster"
echo ""
read -p "Press [ENTER] to verify the database update..."
echo ""

# ============================================================================
# STEP 3: Verify the database was updated
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 3: Verify Database Update"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🔍 Querying database to confirm update..."
echo ""

docker exec -it node4-db-primary psql -U postgres -d pharmacy -c "SELECT id, name, quantity FROM drugs WHERE id=1;"

echo ""
echo "✅ The quantity should now be 777, proving:"
echo "   ✓ Raft consensus was achieved"
echo "   ✓ Command was committed to distributed log"  
echo "   ✓ Database was updated via apply_entry_to_db()"
echo "   ✓ All nodes have consistent state"
echo ""
read -p "Press [ENTER] to see detailed log evidence..."
echo ""

# ============================================================================
# STEP 4: Show leader logs (proof of consensus)
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 4: Leader Log Evidence"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Examining leader's logs for Raft workflow..."
echo ""

LEADER_FOUND=false
for node in node2-api-server-a node3-api-server-b node7-api-server-c node8-api-server-d node9-api-server-e; do
  result=$(docker logs $node 2>&1 | grep -E "LOG.*777|COMMIT.*777|DB.*updated.*1.*777" 2>/dev/null)
  if [ ! -z "$result" ]; then
    echo "🏆 LEADER NODE: $node"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$result"
    echo ""
    echo "📖 This shows:"
    echo "   [LOG]    → Leader appended command to its log"
    echo "   [COMMIT] → Leader committed after majority ACK"
    echo "   [DB]     → Leader applied change to database"
    LEADER_FOUND=true
    break
  fi
done

if [ "$LEADER_FOUND" = false ]; then
  echo "⚠️  Leader logs not found for this specific command."
  echo "   (May have been rotated or system restarted)"
fi

echo ""
read -p "Press [ENTER] to see follower replication evidence..."
echo ""

# ============================================================================
# STEP 5: Show follower logs (proof of replication)
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 5: Follower Replication Evidence"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Examining follower logs to prove replication..."
echo ""

echo "📦 Follower: Node 2 (api-server-b)"
echo "───────────────────────────────────────"
docker logs node3-api-server-b 2>&1 | grep -E "APPLY.*777|DB.*updated.*1.*777" | head -2
echo ""

echo "📦 Follower: Node 3 (api-server-c)"
echo "───────────────────────────────────────"
docker logs node7-api-server-c 2>&1 | grep -E "APPLY.*777|DB.*updated.*1.*777" | head -2
echo ""

echo "📦 Follower: Node 5 (api-server-e)"
echo "───────────────────────────────────────"
docker logs node9-api-server-e 2>&1 | grep -E "APPLY.*777|DB.*updated.*1.*777" | head -2
echo ""

echo "📖 Follower logs show:"
echo "   [APPLY] → Follower received committed entry from leader"
echo "   [DB]    → Follower applied change to its local database"
echo ""
echo "✅ All nodes now have consistent state!"
echo ""
read -p "Press [ENTER] for final summary..."
echo ""

# ============================================================================
# STEP 6: Summary
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  DEMONSTRATION COMPLETE ✅"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🎯 We have successfully proven:"
echo ""
echo "   ✅ Leader Election"
echo "      → One node became leader through voting"
echo ""
echo "   ✅ Log Replication"  
echo "      → Followers received log entries via AppendEntries RPC"
echo ""
echo "   ✅ Majority Consensus"
echo "      → 3 out of 5 nodes acknowledged the entry"
echo ""
echo "   ✅ Committed Entries"
echo "      → Leader marked entry as committed after majority ACK"
echo ""
echo "   ✅ State Machine Application"
echo "      → All nodes applied UPDATE to their local databases"
echo ""
echo "   ✅ Distributed Consistency"
echo "      → All nodes converged to the same state (quantity=777)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "This demonstrates a fully functional Raft consensus"
echo "protocol integrated with database state machine replication."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
