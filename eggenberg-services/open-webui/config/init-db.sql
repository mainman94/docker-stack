-- Runs only on the very first start, while the data directory is still empty.
-- Creates the databases for LiteLLM and mem0 next to "openwebui".
--
-- mem0 needs two: "mem0" stores the pgvector memories, "mem0_app" the users,
-- API keys and request logs. Only the vector one needs the extension.

CREATE DATABASE litellm;
CREATE DATABASE mem0;
CREATE DATABASE mem0_app;

\connect openwebui
CREATE EXTENSION IF NOT EXISTS vector;

\connect mem0
CREATE EXTENSION IF NOT EXISTS vector;
