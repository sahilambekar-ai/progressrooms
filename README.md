# ProgressRooms

ProgressRooms is a production-grade multi-tenant operating platform for teachers, instructors, trainers, coaches, and studios who conduct scheduled classes, workshops, and training programs.

## Architecture

This workspace contains the web and API repositories:

1. [`progressrooms-web`](https://github.com/sahilambekar-ai/progressrooms-web): Frontend application built with Next.js 14 (App Router, SSR, TypeScript, Tailwind CSS). Includes the studio dashboard, website editor, and server-rendered studio landing pages.
2. [`progressrooms-api`](https://github.com/sahilambekar-ai/progressrooms-api): Backend API service built with FastAPI, SQLAlchemy 2.0 (async), PostgreSQL, Alembic, and Razorpay commerce integration.

Shared engineering specifications and architectural design documents are maintained in [`docs/`](./docs).

## Quick Start (Local Development)

### 1. Start Infrastructure
```bash
docker compose up -d
```
This spins up PostgreSQL 16 on `localhost:5432` and Redis 7 on `localhost:6379`.

### 2. Start Backend API
```bash
cd progressrooms-api
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
alembic upgrade head
python -m scripts.seed.seed_data
uvicorn app.main:app --reload --port 8000
```
Interactive API docs will be available at `http://localhost:8000/docs`.

### 3. Start Frontend Web
```bash
cd progressrooms-web
npm install
npm run dev
```
Web app will be available at `http://localhost:3000`. Studio owners can navigate to **My Website** directly within the dashboard side panel without starting any separate application.
