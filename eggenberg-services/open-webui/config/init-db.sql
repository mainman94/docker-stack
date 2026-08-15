-- Runs only on the very first start, while the data directory is still empty.
-- Creates the LiteLLM database next to "openwebui".
--
-- Open WebUI keeps chats, users, RAG chunks and memories in "openwebui" and
-- needs the vector extension there.

CREATE DATABASE litellm;

\connect openwebui
CREATE EXTENSION IF NOT EXISTS vector;
