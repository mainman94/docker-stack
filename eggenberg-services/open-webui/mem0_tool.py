"""
title: mem0 Memory Search
description: Lets the model look up what is known about the user, on demand.
author: -
version: 0.1.0
requirements: httpx
"""

# NOT mounted. Install via:
#   Workspace -> Tools -> "+" -> paste this code -> save,
#   then set the API key in the valves and enable the tool on the model.
#
# Counterpart to mem0_filter.py: the filter shows a short index once per chat,
# this tool fetches the detail. Requires a model that can call tools — through
# LiteLLM that means claude-opus or gpt-5, not the task model.
#
# The self-hosted OSS server's endpoints have NO /v1/ prefix (unlike mem0
# Cloud). When in doubt, check http://open-webui-mem0:8000/docs.

import httpx
from pydantic import BaseModel, Field


def _format_hits(hits: list, threshold: float, limit: int) -> str:
    """Numbered list of relevant memories, or a plain miss message."""
    facts = [
        (h.get("memory") or "").strip()
        for h in hits
        if h.get("score", 1.0) >= threshold
    ]
    facts = [f for f in facts if f][:limit]
    if not facts:
        return "No memories found for that query."
    return "\n".join(f"{i}. {f}" for i, f in enumerate(facts, 1))


class Tools:
    class Valves(BaseModel):
        mem0_url: str = Field(
            default="http://open-webui-mem0:8000",
            description="Base URL of the mem0 server",
        )
        api_key: str = Field(
            default="",
            description="X-API-Key from the mem0 dashboard",
        )
        limit: int = Field(
            default=8,
            description="Maximum number of memories returned per call",
        )
        threshold: float = Field(
            default=0.35,
            description="Minimum relevance. Below this a hit is dropped.",
        )

    def __init__(self):
        self.valves = self.Valves()
        # Results are data for the model, not a document to cite.
        self.citation = False

    async def search_memory(self, query: str, __user__: dict | None = None) -> str:
        """
        Look up long-term memories about the current user. Use this when the
        conversation touches their preferences, setup, history or past
        decisions, and the answer is not already in the chat.

        :param query: What to look for, in natural language.
        :return: A numbered list of relevant memories, or a miss message.
        """
        if not __user__:
            return "No user context available, cannot search memory."

        try:
            async with httpx.AsyncClient(timeout=8.0) as client:
                response = await client.post(
                    f"{self.valves.mem0_url}/search",
                    headers={"X-API-Key": self.valves.api_key},
                    json={
                        "query": query,
                        "user_id": __user__["id"],
                        "limit": self.valves.limit,
                    },
                )
                response.raise_for_status()
                hits = response.json().get("results", [])
        except Exception as exc:
            # Tell the model it failed — it can then answer without memory
            # instead of silently pretending the user has none.
            return f"Memory lookup failed: {exc}"

        return _format_hits(hits, self.valves.threshold, self.valves.limit)


if __name__ == "__main__":
    # Smallest check that fails if filtering or formatting breaks.
    assert _format_hits([], 0.35, 8) == "No memories found for that query."
    assert _format_hits([{"memory": "a", "score": 0.1}], 0.35, 8).startswith("No memories")
    assert _format_hits([{"memory": "  ", "score": 0.9}], 0.35, 8).startswith("No memories")

    hits = [
        {"memory": "runs TrueNAS", "score": 0.9},
        {"memory": "prefers Postgres", "score": 0.5},
        {"memory": "irrelevant", "score": 0.2},
    ]
    assert _format_hits(hits, 0.35, 8) == "1. runs TrueNAS\n2. prefers Postgres"
    assert _format_hits(hits, 0.35, 1) == "1. runs TrueNAS"
    # A hit without a score must not be dropped.
    assert _format_hits([{"memory": "no score"}], 0.35, 8) == "1. no score"

    print("ok")
