# 🎬 Demo Recording Script (Loom)

A ~3-4 minute walkthrough of the RAG Voice AI Agent. Narration is in *italics*; actions
are in **bold**. Uses the sample manual in `demo/sample_manual.md`.

---

## 0. Before you hit record (setup — off camera)

1. Make sure `backend/.env` has all 5 keys (Deepgram, Groq, Google, ElevenLabs, Mongo).
2. Start the app:
   ```bash
   docker-compose up --build
   ```
3. Seed the demo data (creates the equipment + uploads the sample manual):
   ```bash
   ./demo/seed.sh
   ```
4. Open http://localhost:3000 in Chrome. Have `demo/sample_manual.md` open in a tab so you
   can show the source facts if you want.
5. Test your mic once so you're not debugging on camera.

---

## 1. Intro (~20s)

> *"This is a real-time voice AI agent that helps support agents answer customer questions.*
> *You talk to it, and it answers out loud — but the key part is it only answers from a*
> *knowledge base using RAG, so it doesn't make things up. Let me show you."*

**Show the app on screen.**

---

## 2. What's under the hood (~20s)

> *"Under the hood: your voice goes to Deepgram for speech-to-text, then a Groq LLM. The*
> *LLM doesn't answer from memory — it calls a search tool that runs a vector search over*
> *documents in MongoDB using Gemini embeddings. The answer is spoken back with ElevenLabs,*
> *and I'll show you the exact source passages it used on screen."*

(Optional: briefly show the architecture diagram in the README.)

---

## 3. Connect (~15s)

**Point at the equipment dropdown.**

> *"I've already loaded a manual for a Pump X200. I'll select it and connect."*

**Select "Pump X200" → click Connect → allow microphone access.**

> *"It connects over a WebSocket and greets me — that's the live pipeline starting up."*

---

## 4. The core demo — ask questions (~90s)

Ask these out loud, one at a time. Wait for each spoken answer and **point at the source
chunk panel** each time.

**Q1 — direct fact:**
> *"What's the maximum operating pressure of the pump?"*
> Expected: **150 psi.** → *"Notice the source chunk it pulled up on the right — that's the*
> *actual manual text it based the answer on."*

**Q2 — price (shows integer formatting):**
> *"How much is a replacement inlet filter?"*
> Expected: **45 dollars.**

**Q3 — procedure (shows summarization):**
> *"How do I reset the pump after a thermal overload?"*
> Expected: a short spoken version of the 4-step reset procedure.

**Q4 — follow-up (shows conversation memory):**
> *"And how often should I clean the filter?"*
> Expected: **every 30 days.**

---

## 5. The money shot — no hallucination (~30s)

> *"Now the important part. I'll ask something that is NOT in the manual."*

**Ask:**
> *"What's the warranty period on the motor?"*

> *"There's no warranty info in the document — so instead of inventing an answer, it tells*
> *me it doesn't have that information. That's the whole point of grounding it in RAG."*

*(Optional)* **Start talking while it's mid-answer** to show barge-in / interruption
handling:
> *"I can also interrupt it mid-sentence and it stops and listens — natural turn-taking."*

---

## 6. Wrap (~20s)

> *"So that's the agent: real-time voice in and out, answers grounded only in the uploaded*
> *documents, with the sources shown for verification. Everything's containerized and*
> *deploys to AWS ECS. Code and full write-up are in the README. Thanks for watching."*

---

## Quick cheat-sheet (answers to expect from the sample manual)

| Question | Expected answer |
|---|---|
| Max operating pressure? | 150 psi |
| Max flow rate? | 220 gallons per minute |
| Replacement inlet filter cost? | 45 dollars |
| Mechanical seal kit cost? | 120 dollars |
| How to reset after overload? | Power off, wait 5 min, hold red reset 3s, open inlet valve, power on |
| How often to clean the filter? | Every 30 days |
| Max fluid temperature? | 90 degrees Celsius |
| **Warranty period?** (not in doc) | Should say it doesn't have that info |
