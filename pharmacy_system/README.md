# 💊 Distributed Pharmacy Inventory Management System

**CSE-5306 Distributed Systems — Project 3**

## System Overview

A distributed pharmacy inventory management system built with two architectures:
1. **gRPC Microservice** — 6 containerized nodes with load balancing and DB replication
2. **REST Monolith** — single containerized service for comparison

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

### gRPC Microservice (6 Nodes)

```
Client (Python)
      ↓ gRPC
Node 1: NGINX Load Balancer       (port 8080)
   ↙              ↘
Node 2: gRPC API Server A         (port 50051)
Node 3: gRPC API Server B         (port 50051)
      ↓
Node 4: PostgreSQL Primary DB     (port 5432)
      ↓ streaming replication
Node 5: PostgreSQL Replica DB     (port 5433)

Node 6: pgAdmin Monitor Panel     (port 5050)
```

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

### Step 7 — Test REST Monolith

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

### Step 8 — Run Performance Benchmark

```bash
cd evaluation
python benchmark.py
python plot_results.py
```

### Step 9 — View pgAdmin Dashboard (Node 6)

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

## AI Tools Usage

This project was developed with assistance from Claude (Anthropic) for:
- System architecture design
- Proto file generation
- Docker configuration
- Benchmark script creation
- Report writing

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
