"""
title: mem0 Memory Index
description: Injects a compact memory index once per chat and records each turn.
author: -
version: 0.2.0
requirements: httpx
"""

# NOT mounted. Install via:
#   Admin Panel -> Functions -> "+" -> paste this code -> save,
#   then enable it, set the API key in the valves and assign it to the model.
#
# Pair it with mem0_tool.py, which does the actual lookup. Split of work:
#
#   this filter  -> one short index (titles only) on the FIRST turn of a chat,
#                   plus writing every finished turn back to mem0
#   the tool     -> full memory text, fetched only when the model asks for it
#
# That is the cheap half of the trade: injecting search hits into every single
# request costs 5-7k tokens per message forever. An index costs that once per
# chat, and the model pulls detail only where it actually needs it.
#
# The self-hosted OSS server's endpoints have NO /v1/ prefix (unlike mem0
# Cloud). When in doubt, check http://open-webui-mem0:8000/docs.

import httpx
from pydantic import BaseModel, Field


def _is_first_turn(messages: list) -> bool:
    """True while the chat has no assistant reply yet."""
    return not any(m.get("role") == "assistant" for m in messages)


def _format_index(memories: list, max_items: int, max_chars: int) -> str:
    """One truncated line per memory. Empty string when there is nothing."""
    lines = []
    for m in memories[:max_items]:
        text = (m.get("memory") or "").strip().replace("\n", " ")
        if not text:
            continue
        if len(text) > max_chars:
            text = text[: max_chars - 1].rstrip() + "…"
        lines.append(f"- {text}")
    if not lines:
        return ""
    return (
        "Known about this user (index, may be truncated). Call search_memory "
        "when you need the full wording or something not listed here:\n"
        + "\n".join(lines)
    )


class Filter:
    class Valves(BaseModel):
        mem0_url: str = Field(
            default="http://open-webui-mem0:8000",
            description="Base URL of the mem0 server",
        )
        api_key: str = Field(
            default="",
            description="X-API-Key: the stack's MEM0_ADMIN_API_KEY",
        )
        index_items: int = Field(
            default=40,
            description="Maximum number of memories listed in the index",
        )
        index_chars: int = Field(
            default=100,
            description="Maximum characters per index line",
        )
        write_turns: bool = Field(
            default=True,
            description="Send finished turns to mem0 for extraction",
        )
        enabled: bool = Field(default=True)

    def __init__(self):
        self.valves = self.Valves()

    def _headers(self) -> dict:
        return {"X-API-Key": self.valves.api_key}

    # -- first turn only: hand the model a table of contents -----------------
    async def inlet(self, body: dict, __user__: dict | None = None) -> dict:
        if not self.valves.enabled or not __user__:
            return body

        messages = body.get("messages", [])
        # Every later turn already carries the index in its history.
        if not _is_first_turn(messages):
            return body

        try:
            async with httpx.AsyncClient(timeout=8.0) as client:
                response = await client.get(
                    f"{self.valves.mem0_url}/memories",
                    headers=self._headers(),
                    params={"user_id": __user__["id"]},
                )
                response.raise_for_status()
                payload = response.json()
        except Exception:
            # Memory is a nice-to-have, not a blocker. If it fails, keep chatting.
            return body

        # The server returns either a bare list or {"results": [...]}.
        memories = payload if isinstance(payload, list) else payload.get("results", [])
        block = _format_index(memories, self.valves.index_items, self.valves.index_chars)
        if not block:
            return body

        if messages and messages[0].get("role") == "system":
            messages[0]["content"] = f"{messages[0]['content']}\n\n{block}"
        else:
            messages.insert(0, {"role": "system", "content": block})

        body["messages"] = messages
        return body

    # -- after the answer: push the new turn back for extraction -------------
    async def outlet(self, body: dict, __user__: dict | None = None) -> dict:
        if not self.valves.enabled or not self.valves.write_turns or not __user__:
            return body

        messages = body.get("messages", [])
        turn = [
            {"role": m["role"], "content": m["content"]}
            for m in messages[-2:]
            if m.get("role") in ("user", "assistant")
            and isinstance(m.get("content"), str)
        ]
        if len(turn) < 2:
            return body

        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                await client.post(
                    f"{self.valves.mem0_url}/memories",
                    headers=self._headers(),
                    json={"messages": turn, "user_id": __user__["id"]},
                )
        except Exception:
            pass

        return body


if __name__ == "__main__":
    # Smallest check that fails if the index or first-turn logic breaks.
    assert _is_first_turn([{"role": "user", "content": "hi"}])
    assert not _is_first_turn(
        [{"role": "user", "content": "hi"}, {"role": "assistant", "content": "yo"}]
    )
    assert _format_index([], 10, 50) == ""
    assert _format_index([{"memory": "   "}], 10, 50) == ""

    out = _format_index([{"memory": "likes Postgres"}, {"memory": "runs TrueNAS"}], 1, 50)
    assert "- likes Postgres" in out
    assert "TrueNAS" not in out, "max_items must cap the list"

    out = _format_index([{"memory": "x" * 80}], 10, 20)
    assert out.endswith("…") and len(out.splitlines()[-1]) == 22, out.splitlines()[-1]

    print("ok")
