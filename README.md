# 🎙️ RAG Voice AI Agent

A real-time **voice AI agent** that helps call-center / support agents answer customer
questions instantly. The agent listens to a spoken question, retrieves the most relevant
facts from an equipment-specific knowledge base using **Retrieval-Augmented Generation
(RAG)**, and speaks a concise, grounded answer back — all in a live, low-latency
conversation. The exact source passages it used are shown on screen for verification.

> Built to explore how far a low-latency, tool-calling voice agent can go when it is
> **forced to answer only from a vector-searched knowledge base** instead of hallucinating.

---

## 📽️ Demo

<!-- Replace the link below with your Loom video / add screenshots to a /docs/screenshots folder -->
- **Video walkthrough:** [Loom link here](#)
- **Screenshots:**

| Live conversation | Retrieved source chunks |
|---|---|
| _screenshot_ | _screenshot_ |

---

## ✨ Features

- **Real-time voice conversation** — barge-in / interruptions, voice-activity detection,
  and smart end-of-turn detection so it feels like a natural phone call.
- **Grounded answers (RAG)** — the LLM cannot answer freely; it must call a
  `search_knowledge_base` tool that runs a MongoDB Atlas vector search. Answers use only
  retrieved facts.
- **Per-equipment knowledge bases** — upload manuals/specs per machine; retrieval is
  scoped by `equipment_id` and `tenant_id` (multi-tenant ready).
- **Live source transparency** — every retrieved chunk (text + metadata + similarity
  score) is streamed to the UI so you can see *why* the agent said what it said.
- **Document ingestion pipeline** — upload `.pdf`, `.docx`, `.txt`, or `.md`; the backend
  extracts, chunks, embeds, and indexes automatically.
- **Speech-optimized responses** — the system prompt constrains answers to short, spoken
  sentences (no JSON, no markdown, prices as integers).

---

## 🏗️ Architecture

```
                    ┌──────────────────────────────────────────────┐
   🎧 Browser  ─────►  React + Vite + Pipecat JS client             │
   (mic/audio)      │  • picks equipment, opens WebSocket            │
        ▲           └───────────────┬──────────────────────────────┘
        │ spoken answer + chunks     │ audio (WebSocket, protobuf frames)
        │                            ▼
┌───────┴────────────────────────────────────────────────────────────┐
│  FastAPI backend  +  Pipecat pipeline                               │
│                                                                     │
│   audio in ─► Deepgram STT ─► Groq LLM ─► ElevenLabs TTS ─► audio out│
│                                  │                                   │
│                                  ▼  tool call: search_knowledge_base │
│                          ┌───────────────┐                          │
│                          │  RAG Service  │                          │
│                          └───────┬───────┘                          │
│               Gemini embedding + │  $vectorSearch                   │
└──────────────────────────────────┼──────────────────────────────────┘
                                   ▼
                        MongoDB Atlas (Vector Search)
                        document_chunks + equipment
```

**Request lifecycle**

1. Frontend calls `POST /api/v1/stream/connect` with an `equipment_id`; backend validates
   it and returns a `ws_url`.
2. Browser opens the WebSocket; the [Pipecat](https://pipecat.ai) pipeline spins up per
   connection ([`bot.py`](backend/app/bot.py)).
3. Mic audio → **Deepgram** speech-to-text → **Groq** LLM.
4. When the customer asks something, the LLM calls the `search_knowledge_base` function
   tool → **RAGService** embeds the query with **Gemini** and runs an Atlas
   `$vectorSearch` filtered by `equipment_id` / `tenant_id`.
5. Retrieved chunks are returned to the LLM (to ground the answer) **and** pushed to the
   UI via an RTVI server message.
6. The spoken answer → **ElevenLabs** text-to-speech → streamed back to the browser.

---

## 🧰 Tech Stack

| Layer | Technology |
|---|---|
| **Voice orchestration** | [Pipecat](https://pipecat.ai) (VAD: Silero, turn-taking: Local Smart Turn v3, RTVI) |
| **Speech-to-Text** | Deepgram (streaming, diarization) |
| **LLM** | Groq (`openai/gpt-oss-20b`) with function/tool calling |
| **Text-to-Speech** | ElevenLabs |
| **Embeddings** | Google Gemini (`gemini-embedding-001`, 768-dim) |
| **Vector DB** | MongoDB Atlas Vector Search |
| **Backend** | FastAPI, Motor (async MongoDB), Pydantic, Loguru, `uv` |
| **Frontend** | React 18, TypeScript, Vite, Tailwind, Pipecat React client |
| **Transport** | WebSocket (protobuf-serialized audio frames) |
| **Infra / Deploy** | Docker, docker-compose, AWS ECS Fargate + ALB, CloudFormation, GitHub Actions |

---

## 📂 Project Structure

```
rag_voice_ai_agent/
├── backend/
│   ├── main.py                     # FastAPI app, CORS, lifespan, routers
│   └── app/
│       ├── bot.py                  # Pipecat voice pipeline (STT→LLM→TTS + RAG tool)
│       ├── config.py               # Pydantic settings (env-driven)
│       ├── database.py             # Async MongoDB (Motor) connection
│       ├── routers/
│       │   ├── equipment.py        # CRUD + document upload/ingestion
│       │   └── stream.py           # /connect + WebSocket voice endpoint
│       ├── services/
│       │   ├── rag.py              # Vector search retrieval
│       │   ├── embeddings.py       # Gemini embeddings + text chunking
│       │   └── text_extraction.py  # PDF / DOCX / TXT extraction
│       └── models/                 # Pydantic models (equipment, document, rag)
├── frontend/
│   └── src/
│       ├── pages/Stream.tsx        # Pipecat client provider
│       ├── components/RealTimeChatPanel.tsx  # Connect, mic, transcript, chunks
│       └── utils/api.ts            # Axios client
├── infrastructure/                 # CloudFormation + AWS setup scripts
├── scripts/                        # ECR build/push + ECS service scripts
├── .github/workflows/              # CI/CD (build → ECR → ECS deploy)
├── docker-compose.yml
├── DEPLOYMENT.md                   # Full AWS production deployment guide
└── README.md
```

---

## 🚀 Getting Started (Local)

### Prerequisites

- **Docker Desktop** (for the compose path) or **Python 3.12+ with [`uv`](https://docs.astral.sh/uv/)** and **Node 20+** for local dev.
- A **MongoDB Atlas** cluster.
- API keys: **Deepgram**, **Groq**, **Google AI (Gemini)**, **ElevenLabs**.

### 1. MongoDB Atlas Vector Index

Create a database (e.g. `rag_voice_agent_db`) and a **Vector Search index** named
`vector_index` on the `document_chunks` collection:

```json
{
  "fields": [
    { "type": "vector", "path": "embedding", "numDimensions": 768, "similarity": "cosine" },
    { "type": "filter", "path": "equipment_id" },
    { "type": "filter", "path": "tenant_id" },
    { "type": "filter", "path": "is_disabled" }
  ]
}
```

> `numDimensions` **must be 768** to match `gemini-embedding-001`.

### 2. Environment variables

Create `backend/.env`:

```env
MONGO_URL=mongodb+srv://<user>:<pass>@<cluster>.mongodb.net
DB_NAME=rag_voice_agent_db
DEEPGRAM_API_KEY=your_key
GROQ_API_KEY=your_key
GOOGLE_API_KEY=your_key
ELEVENLABS_API_KEY=your_key        # required for voice output
```

### 3a. Run with Docker Compose (easiest)

```bash
docker-compose up --build
```

- Frontend: http://localhost:3000
- Backend:  http://localhost:8000
- API docs: http://localhost:8000/docs

### 3b. Run locally without Docker

```bash
# Backend
cd backend
uv sync
uv run uvicorn main:app --reload --port 8000

# Frontend (new terminal)
cd frontend
echo "VITE_API_BASE_URL=http://localhost:8000/api/v1" >> .env
echo "VITE_PIPECAT_ENDPOINT=/stream/connect" >> .env
npm install
npm run dev        # http://localhost:5173
```

### 4. Seed a knowledge base

The app starts empty — add an equipment and a document before connecting. Use the Swagger
UI at http://localhost:8000/docs:

1. `POST /api/v1/equipment/`
   ```json
   { "name": "Pump X200", "description": "Industrial water pump", "tenant_id": "mvp_tenant" }
   ```
   > `tenant_id` **must be `mvp_tenant`** — the bot filters retrieval on this value.
2. `POST /api/v1/equipment/{equipment_id}/documents` — upload a `.pdf`, `.docx`, `.txt`,
   or `.md` manual. The backend extracts → chunks → embeds → indexes it.

### 5. Talk to it

Open the frontend, select the equipment, click **Connect**, allow microphone access, and
ask a question about the uploaded document. The agent answers by voice and shows the source
chunks it used.

---

## 🔌 Key API Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | Health check |
| `POST` | `/api/v1/equipment/` | Create equipment |
| `GET` | `/api/v1/equipment/` | List equipment |
| `POST` | `/api/v1/equipment/{id}/documents` | Upload & ingest documents |
| `GET` | `/api/v1/equipment/{id}/documents` | List documents |
| `POST` | `/api/v1/stream/connect` | Get WebSocket URL for a session |
| `WS` | `/api/v1/stream/ws/{equipment_id}` | Live voice pipeline |

---

## 🛠️ How I Built It

I designed this in three layers, building bottom-up:

1. **RAG ingestion & retrieval first.** I started with the "boring" but critical part:
   getting documents into a searchable form. I built a text-extraction service
   (`pypdf` / `python-docx`), a recursive character chunker (1000 chars, 250 overlap), and
   a Gemini embedding service, then stored chunks in MongoDB Atlas and wired up
   `$vectorSearch`. I validated retrieval quality with plain HTTP calls **before** adding
   any voice, so I could isolate "is retrieval good?" from "is the voice pipeline working?".

2. **The voice pipeline.** I used Pipecat to compose the real-time pipeline
   (`transport → STT → LLM → TTS → transport`) over a FastAPI WebSocket. The key design
   decision was to **expose retrieval as an LLM tool** (`search_knowledge_base`) rather than
   stuffing context in the prompt — this lets the model decide when it needs facts and keeps
   turns fast when it doesn't.

3. **The frontend & observability.** I built a React UI on the Pipecat client that not only
   handles the audio session but also renders the retrieved chunks in real time (via RTVI
   server messages), which was invaluable for debugging grounding.

4. **Deployment.** Containerized both services, then automated AWS provisioning with
   CloudFormation (ECS Fargate + ALB, ECR, Secrets Manager) and a GitHub Actions CI/CD
   pipeline. See [DEPLOYMENT.md](DEPLOYMENT.md).

---

## 🧗 Challenges & What I Learned

- **Latency budgeting.** A voice agent lives or dies on response time. STT → LLM → RAG →
  TTS all add up. Making retrieval a *tool call* (only when needed) and keeping answers
  short (<30 words, enforced in the system prompt) kept conversations snappy.
- **Turn-taking.** Naive silence detection cuts users off. I added Silero VAD plus a
  Local Smart Turn v3 analyzer so the agent waits for genuine end-of-turn instead of any
  pause.
- **Forcing grounding.** LLMs love to answer from memory. The system prompt + tool design
  constrain the model to answer *only* from retrieved chunks and to defer when the KB has
  no answer — reducing hallucination.
- **Embedding/index dimension mismatch.** Switching the embedding model
  (`text-embedding-004` → `gemini-embedding-001`) meant the Atlas vector index dimensions
  had to match exactly (768). A mismatch silently breaks retrieval — a good reminder that
  the index and the embedding model are tightly coupled.
- **WebSockets through a load balancer.** Getting `wss://` to work behind an AWS ALB
  required forwarding proto/host headers correctly and tuning the ALB idle timeout for
  long-lived audio streams (see [stream.py](backend/app/routers/stream.py) and
  [DEPLOYMENT.md](DEPLOYMENT.md) troubleshooting).
- **Multi-tenancy from day one.** Scoping every chunk by `equipment_id` and `tenant_id`
  meant retrieval filters were part of the schema from the start, not bolted on later.

---

## 📊 Results

<!-- Fill in with your own measured numbers / observations from the demo -->

- ✅ End-to-end spoken Q&A grounded in uploaded documents, with visible source chunks.
- ✅ Supports PDF / DOCX / TXT / MD ingestion with automatic chunking + embedding.
- ⏱️ Typical spoken response latency: _add your measured number_.
- 🎯 Retrieval quality: _add notes / example queries and the chunks returned_.

**Example interaction**

> **Customer:** "What's the maximum operating pressure of the X200 pump?"
> **Agent:** _"The maximum operating pressure is 150 psi."_ (grounded in the uploaded manual;
> source chunk shown in the panel)

---

## ☁️ Production Deployment

Full AWS deployment (ECS Fargate + ALB via CloudFormation and GitHub Actions CI/CD) is
documented in **[DEPLOYMENT.md](DEPLOYMENT.md)**.

---

## 🔮 Future Improvements

- Reranking retrieved chunks before answering.
- Conversation memory / summarization across turns.
- Streaming partial transcripts to the UI for lower perceived latency.
- Evaluation harness for retrieval quality and answer faithfulness.
- Auth + per-user tenants (currently a single hard-coded tenant/user for the MVP).

---

## 📜 License

Add a license of your choice (e.g. MIT).
```
