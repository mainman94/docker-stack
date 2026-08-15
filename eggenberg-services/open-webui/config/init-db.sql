-- Runs only on the very first start, while ./postgres/data is still empty.
-- Creates the LiteLLM and mem0 databases next to "openwebui".

CREATE DATABASE litellm;
CREATE DATABASE mem0;

\connect openwebui
CREATE EXTENSION IF NOT EXISTS vector;

\connect mem0
CREATE EXTENSION IF NOT EXISTS vector;
