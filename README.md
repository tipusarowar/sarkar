# 🇧🇩 BanglaGov-LLM: Bangladesh Government Citizen Services AI
### নাগরিক সেবা AI: বাংলাদেশ সরকারের সেবা ও নাগরিক সমস্যা সমাধানে নিবেদিত এআই

Citizens ask in **Bengali (বাংলা)**, **English** or **Banglish** how to obtain a government service or solve a problem with a government office. The system answers **from official `*.gov.bd` content only** and shows where each answer came from.

**Design (version 2, October 2026): retrieval first, not training first.** Fees, documents and deadlines change by gazette, and a model that has memorised them cannot say where a figure came from. So the system:
1. collects and indexes official content: curated service entries plus crawled `*.gov.bd` pages and PDFs;
2. finds the most relevant passages for each question, using keyword search plus optional semantic search that works across languages;
3. writes the answer either with the built-in templates or with an AI model that may use **only** those passages, citing them as [1], [2] …

Fine-tuning a model (the `training/` folder) is a later step for tone and Bengali fluency. It needs thousands of real question-and-answer pairs and should not be used to teach facts.

---

## 🌟 What it does

| Area | Details |
| :--- | :--- |
| **Answers** | Curated service guides (fees, documents, steps, time limit, GRS route), plus passages from crawled official pages with links and retrieval dates. With an AI model connected, answers are written from the sources with numbered citations. |
| **Verified facts** | Each service is **verified** (checked by the responsible office, shown with who verified it and when), **unreviewed** (shown with a warning to confirm on the portal) or **draft** (hidden from citizens). 11 services are unreviewed and 39 more are drafts waiting to be completed. |
| **Crawler** | Follows links within each site, reads sitemaps, respects robots.txt, reads **PDFs** (Citizen Charters, gazettes), can open **JavaScript-built pages** in a headless browser, skips unchanged pages, and flags legacy **Bijoy/SutonnyMJ** text. Covers 118 national sites plus, optionally, the 64 district portals. |
| **Search** | Passages with keyword (BM25) search, a directory of official websites (so "Ministry of Foreign Affairs" or "চাঁদপুরের ডিসি" finds the right site), and optional semantic search (e.g. bge-m3 via Ollama). |
| **Safety** | Answers only from sources; citation check (an AI answer without citations is replaced by the built-in answer); anti-broker warnings; NID, mobile and e-mail numbers are masked before storage or sending to an AI service; web page output is escaped. |
| **Feedback** | 👍/👎 on every answer; the admin page lists unhelpful answers and questions no service matched. |
| **Voice** | Voice input and read-aloud (the browser's speech features; a Bengali voice must be installed on the device). |
| **GRS petition drafter** | Formal Bengali/English grievance petition for grs.gov.bd (nothing is stored). |
| **Evaluation** | 100-question test set with a runner that measures service choice, facts, source sites and citations. |

---

## 🚀 Quick start (Windows)

Node.js **22.5 or newer** is required (it includes the built-in SQLite). Either Antigravity's bundled Node or a normal install from nodejs.org works. A normal install also gives you `npm`, which is needed for PDF reading.

```powershell
cd D:\Antigravity
npm install                      # optional: enables PDF reading (pdfjs-dist)
copy .env.example .env           # then edit .env (at least BANGLAGOV_ADMIN_TOKEN)
node server\server.js            # open http://localhost:3000  and  http://localhost:3000/admin.html
node tests\test_suite.js         # automated tests
```

With Antigravity's Node instead of `node`:
```powershell
& "C:\Users\Hi\AppData\Roaming\Antigravity\bin\agy-node.cmd" "d:\Antigravity\server\server.js"
```

### Crawl official websites
```powershell
node scraper\crawler.js                        # 118 national sites, up to 40 pages each (takes a few hours)
node scraper\crawler.js --only-districts       # the 64 district portals (DC offices)
node scraper\crawler.js https://mofa.gov.bd --max-pages 100
node scraper\crawler.js --single               # old behaviour: home pages only
```
For JavaScript-built sites (epassport, mutation.land, etaxnbr …): `npm install playwright` then `npx playwright install chromium`. The crawler uses the browser automatically when a page has almost no text. Re-run the crawl regularly (e.g. weekly with Windows Task Scheduler); unchanged pages are skipped.

### Connect an AI model and semantic search (local, free, data stays on the computer)
1. Install Ollama from https://ollama.com, then:
   ```powershell
   ollama pull qwen2.5:7b      # answer-writing model (try others for Bengali quality)
   ollama pull bge-m3          # multilingual embeddings for semantic search
   ```
2. In `.env`:
   ```
   BANGLAGOV_LLM_ENDPOINT=http://localhost:11434/v1/chat/completions
   BANGLAGOV_MODEL_NAME=qwen2.5:7b
   BANGLAGOV_EMBED_ENDPOINT=http://localhost:11434/v1/embeddings
   BANGLAGOV_EMBED_MODEL=bge-m3
   ```
3. `node scripts\embed.js` (creates vectors for already-crawled passages), then restart the server.

Any OpenAI-compatible endpoint works (LM Studio, vLLM, hosted providers). With a hosted provider, citizens' questions (with personal numbers masked) leave the country; for a government service, prefer a self-hosted model.

### Verify services (admin page)
1. Set `BANGLAGOV_ADMIN_TOKEN` in `.env`, restart, and open `/admin.html`.
2. **Services** tab: open a service, fill in or correct fees, documents, steps, time limit, helpline and keywords, using the office's published Citizen Charter.
3. When the responsible office has confirmed it, enter the officer's name and designation and click **Save & mark verified**. Citizens then see "✅ Verified information: <officer>, <date>".
4. **Export JSON** saves all entries; admin edits are never overwritten when the seed files are reloaded.

### Measure quality
```powershell
node eval\run_eval.js                 # built-in answers
node eval\run_eval.js --llm           # with the AI model from .env
```
The expected facts come from the unverified seed file, so this measures consistency, not truth. Several matching rules were tuned on these same questions, so real citizens' questions will score lower. Add real questions (e.g. from 333) with officially confirmed answers.

### Pilot deployment (server)
```bash
docker compose up -d                  # app only
docker compose --profile ai up -d     # app + Ollama (see docker-compose.yml)
```
Put it behind HTTPS (nginx, IIS or the ministry's reverse proxy) and set `BANGLAGOV_TRUST_PROXY=1`.

---

## 📂 Project structure

```text
d:\Antigravity\
├── engine/
│   ├── db.js              # SQLite schema + migrations, FTS5 indexes, passages
│   ├── rag_engine.js      # service matching, answer templates, verification notes
│   ├── retrieval.js       # hybrid passage search (keyword + directory + semantic)
│   ├── llm_client.js      # AI model connector with numbered sources and citation check
│   ├── embeddings.js      # semantic vectors via OpenAI-compatible endpoint
│   ├── chunker.js         # splits pages/PDFs into passages
│   ├── privacy.js         # masks NID / mobile / e-mail
│   ├── text_utils.js      # stopwords, search terms
│   ├── config.js          # .env loader
│   ├── seed_db.js         # loads services from knowledge_base/*.json
│   └── grs_drafter.js     # GRS petition drafter
├── scraper/crawler.js     # deep *.gov.bd crawler (links, sitemaps, robots, PDFs, JS pages)
├── knowledge_base/
│   ├── seed_services.json     # 11 services (unreviewed)
│   ├── target_services.json   # 39 more services (draft, to be completed and verified)
│   └── site_directory.json    # official websites of ministries, agencies and districts
├── server/server.js       # HTTP server, public + admin API, rate limiting
├── public/                # citizen page (index.html, app.js, style.css) + admin page (admin.html, admin.js)
├── eval/                  # questions.jsonl (100) + run_eval.js
├── tests/test_suite.js    # automated tests
├── scripts/embed.js       # create semantic vectors
├── training/              # fine-tuning pipeline (phase 3)
├── data/banglagov.db      # SQLite database
├── .env.example  Dockerfile  docker-compose.yml  package.json
```

---

## 📡 REST API

| Endpoint | Method | Description |
| :--- | :--- | :--- |
| `/api/chat` | POST `{query, history}` | Answer with sources, `query_id`, `backend` |
| `/api/feedback` | POST `{query_id, rating: 1\|-1, comment}` | Rate an answer |
| `/api/draft-grs` | POST | GRS petition text |
| `/api/services` | GET | Services shown to citizens (drafts hidden) |
| `/api/stats`, `/api/health` | GET | Counts; what is configured |
| `/api/crawl` | POST `{url, deep}` | **Admin**: crawl a page or site |
| `/api/admin/*` | GET/POST/PUT | **Admin**: overview, services (edit/verify), feedback, questions, embed, export |

Admin endpoints need the header `X-Admin-Token: <BANGLAGOV_ADMIN_TOKEN>`.

---

## ⚠️ Known limitations
- The fees and steps in `seed_services.json` were generated during development and **have not been verified**. They are shown with a warning until an office verifies them.
- Legacy Bijoy/SutonnyMJ PDFs are flagged but not converted to Unicode yet; scanned PDFs need OCR.
- District portal domain spellings in the crawler are best-known guesses; the crawl lists any that fail.
- Read-aloud depends on a Bengali voice being installed in the browser or operating system.

## ⚖️ Legal & ethical compliance
- **Right to Information Act, 2009 (তথ্য অধিকার আইন, ২০০৯)**
- **Citizen Charter Guidelines (সিটিজেন চার্টার নির্দেশিকা)**
- **Grievance Redress System guidelines (অভিযোগ প্রতিকার ব্যবস্থা নির্দেশিকা)**
- **Consumer Rights Protection Act, 2009 (ভোক্তা অধিকার সংরক্ষণ আইন, ২০০৯)**
- Only public `*.gov.bd` content is collected; robots.txt is respected; personal numbers are masked in logs.
