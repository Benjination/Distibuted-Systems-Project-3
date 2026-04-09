# 💊 Distributed Pharmacy Inventory Management System

**CSE-5306 Distributed Systems — Project 3**

**Team Members:**
- Madison Gage (Student ID: 1001770778)
- Benjamin Niccum (Student ID: 1002111609)

**GitHub Repository:** https://github.com/Benjination/Distibuted-Systems-Project-3

## System Overview

A distributed pharmacy inventory management system extended with **Two-Phase Commit (2PC)** for atomic stock updates and **Raft consensus** for leader election and log replication. Built on a 5-node gRPC microservice architecture with PostgreSQL replication.

## Project 3 Extensions

This project demonstrates:

1. **Two-Phase Commit (2PC)** — Atomic distributed transactions across 5 nodes
   - Vote Phase (Q1): Participant voting with PrepareTransaction RPC
   - Decision Phase (Q2): Coordinator commits or aborts based on votes
   
2. **Raft Consensus Algorithm** — Distributed leader election and log replication
   - Leader Election (Q3): Randomized timeout-based election with RequestVote RPCs
   - Log Replication (Q4): Leader forwards log entries and commits on majority
   
3. **Failure Testing (Q5)** — Five fault tolerance scenarios
   - Follower exit and rejoin
   - Leader failure and recovery
   - Quorum rule demonstration (2 failures OK, 3 failures lose quorum)

## Six Functional Requirements

| # | Feature | gRPC Method | REST Endpoint |
|---|---------|-------------|---------------|
| 1 | Add Drug | `AddDrug` | `POST /drugs` |
| 2 | Get Drug by ID | `GetDrug` | `GET /drugs/{id}` |
| 3 | Update Stock | `UpdateStock` | `PUT /drugs/{id}/stock` |
| 4 | Delete Drug | `DeleteDrug` | `DELETE /drugs/{id}` |
| 5 | List All Drugs | `ListDrugs` | `GET /drugs` |
| 6 | Low Stock Alert | `GetLowStock` | `GET /drugs/alert/low-stock` |

## Architecture

### gRPC Microservice with 2PC + Raft (5 API Servers)

```
Client (Python)
      ↓ gRPC
Node 1: NGINX Load Balancer              (port 8080)
   ↙      ↓      ↓      ↓      ↘
API Server A (Node 1)                    (ports 50051/50052/50053/50054)
API Server B (Node 2)                    (ports 50051/50052/50054)
API Server C (Node 3)                    (ports 50051/50052/50054)
API Server D (Node 4)                    (ports 50051/50052/50054)
API Server E (Node 5)                    (ports 50051/50052/50054)
      ↓
PostgreSQL Primary DB                    (port 5432)
      ↓ streaming replication
PostgreSQL Replica DB                    (port 5433)

pgAdmin Monitor Panel                    (port 5050)
```

**Port Assignment:**
- **50051** — PharmacyService (original gRPC service, all nodes)
- **50052** — TwoPhaseParticipantService (2PC participant, all nodes, internal)
- **50053** — CoordinatorService (2PC coordinator, Node 1 only, exposed to host)
- **50054** — RaftService (Raft consensus, all nodes, internal cluster communication)

### REST Monolith (Comparison)

```
Client (Python/curl)
      ↓ HTTP
FastAPI Monolith                  (port 9000)
      ↓
PostgreSQL DB                     (internal)
```

## Quick Start

### Prerequisites
- Docker Desktop (must be running)
- Python 3.10+
- Git

### Step 1 — Clone & Setup

```bash
git clone <your-repo-url>
cd pharmacy_system
pip install -r requirements.txt
```

### Step 2 — Start All Services

Proto compilation happens automatically inside Docker at build time (no local `generate_proto.sh` needed).

```bash
cd pharmacy_system
docker-compose up --build -d
```

Wait ~15 seconds for all services to initialize.

### Step 3 — Verify Services Running

```bash
docker ps
```

You should see these containers running:
- `node1-nginx-lb`
- `node2-api-server-a`
- `node3-api-server-b`
- `node7-api-server-c`
- `node8-api-server-d`
- `node9-api-server-e`
- `node4-db-primary`
- `node5-db-replica`
- `node6-pgadmin`
- `monolith-rest-api`
- `mono-db`

### Step 4 — Run Test Client (gRPC / 2PC)

```bash
python client/test_client.py
```

### Step 5 — Run 2PC Client

```bash
python client/twopc_client.py
```

### Step 6 — Observe Raft Leader Election

Leader election starts automatically on boot. Check logs to see election and heartbeats:

```bash
# See which node won the election and its heartbeat output
docker logs node2-api-server-a

# See a follower acknowledging RPCs
docker logs node3-api-server-b

# Follow live output from all 5 API nodes at once
docker-compose logs -f api-server-a api-server-b api-server-c api-server-d api-server-e
```

Expected output on the leader node (e.g. Node 1):
```
[PROJECT 3] RaftService started on port 50054 (Node 1)
[RAFT] Node 1 timeout → CANDIDATE
[RAFT] Node 1 becomes LEADER
Node 1 sends RPC AppendEntries to Node 2
Node 1 sends RPC AppendEntries to Node 3
...
```

Expected output on a follower node (e.g. Node 2):
```
[PROJECT 3] RaftService started on port 50054 (Node 2)
Node 2 runs RPC RequestVote called by Node 1
Node 2 runs RPC AppendEntries called by Node 1
...
```

### Step 7 — Run Q5 Failure Tests

To observe Raft fault tolerance, run the following in one terminal:

```bash
# Filter logs to show only important Raft events (no heartbeat spam)
docker compose logs -f api-server-a api-server-b api-server-c api-server-d api-server-e \
  | grep -E "RAFT|CANDIDATE|LEADER|RequestVote|lost majority|isolated|failed|unreachable|COMMIT|APPLY|Stopping|Restarting"
```

Then in another terminal, run these failure scenarios:

**Test 1 — Follower Exit:**
```bash
docker compose stop api-server-b
# Observe: Cluster continues operating with 4/5 nodes
```

**Test 2 — Follower Rejoin:**
```bash
docker compose start api-server-b
# Observe: Node rejoins as follower
```

**Test 3 — Leader Failure:**
```bash
# First identify current leader from logs, then stop it (example: api-server-a)
docker compose stop api-server-a
# Observe: New election occurs, new leader elected
```

**Test 4 — Leader Rejoin:**
```bash
docker compose start api-server-a
# Observe: Old leader rejoins as follower
```

**Test 5 — Quorum Rule (2 vs 3 Failures):**
```bash
# Stop 2 nodes (cluster still works with 3/5 majority)
docker compose stop api-server-d api-server-e
# Try commands - should work

# Stop 3rd node (loses quorum, cluster stalls)
docker compose stop api-server-c
# Try commands - should fail/timeout

# Restart all to recover
docker compose start api-server-c api-server-d api-server-e
```

### Step 8 — Test REST Monolith

```bash
# Add a drug
curl -X POST http://localhost:9000/drugs \
  -H "Content-Type: application/json" \
  -d '{"name":"Aspirin","quantity":500,"price":2.99,"expiry_date":"2026-12-31","category":"Pain Relief"}'

# List all drugs
curl http://localhost:9000/drugs

# Low stock alert
curl http://localhost:9000/drugs/alert/low-stock?threshold=100
```

### Step 9 — Run Performance Benchmark

```bash
cd evaluation
python benchmark.py
python plot_results.py
```

### Step 10 — View pgAdmin Dashboard (Node 6)

Open http://localhost:5050
- Email: `admin@pharmacy.com`
- Password: `admin`
- Add server: host=`node4-db-primary`, port=5432, user=`postgres`, password=`postgres`

## Stop All Services

```bash
docker-compose down -v
```

## Technology Stack

| Component | Technology |
|-----------|-----------|
| Language | Python 3.11 |
| gRPC Framework | grpcio + protobuf |
| REST Framework | FastAPI + uvicorn |
| Database | PostgreSQL 15 |
| Load Balancer | NGINX |
| Containerization | Docker + Docker Compose |
| Monitoring | pgAdmin 4 |

## Anything Unusual

- **Proto Compilation:** Proto files are compiled automatically inside Docker containers at build time. No need to run `generate_proto.sh` manually on the host.
- **Raft Election Timing:** Leader election uses randomized timeouts (1.5-3.0s) to prevent split votes. First boot may take 3-5 seconds before a leader is elected.
- **2PC Coordinator:** Only Node 1 (api-server-a) runs the CoordinatorService on port 50053. All other nodes are participants only.
- **Log Filtering:** To observe Raft elections without heartbeat spam, use the grep filter shown in the Q5 Failure Testing section.

## External Sources Referenced

1. **Raft Consensus Algorithm**
   - Original Paper: "In Search of an Understandable Consensus Algorithm" by Ongaro & Ousterhout (2014)
   - URL: https://raft.github.io/raft.pdf

2. **Two-Phase Commit Protocol**
   - Distributed Systems Principles and Paradigms by Tanenbaum & Van Steen
   - Course lecture materials (CSE 5306)

3. **gRPC and Protocol Buffers**
   - Official gRPC Python Documentation: https://grpc.io/docs/languages/python/
   - Protocol Buffers Guide: https://protobuf.dev/

4. **AI Assistance**
   - GitHub Copilot (Claude Sonnet 4.6) was used for:
     - Scaffolding proto file extensions for 2PC and Raft
     - Generating boilerplate for gRPC servicer classes
     - Assisting with initial Raft design and implementation strategy
     - Troubleshooting Raft leader election timing and log replication
     - Docker configuration and debugging
     - Report structure and LaTeX formatting

## Project Structure

```
pharmacy_system/
├── proto/                    # gRPC proto definitions
├── node1_nginx/              # NGINX load balancer config
├── node2_api_server/         # gRPC API server (used for nodes 2 & 3)
├── node4_db_primary/         # PostgreSQL primary with init SQL
├── monolith_rest/            # FastAPI REST comparison
├── client/                   # Test client scripts
├── evaluation/               # Benchmark + plotting scripts
├── docker-compose.yml
├── requirements.txt
└── README.md
```
