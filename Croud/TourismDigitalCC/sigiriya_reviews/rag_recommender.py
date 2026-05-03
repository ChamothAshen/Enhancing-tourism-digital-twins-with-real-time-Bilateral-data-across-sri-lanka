# rag_recommender.py
import json
import os
import chromadb
from sentence_transformers import SentenceTransformer
from tavily import TavilyClient
from groq import Groq

# ── Put your API keys here ────────────────────────────────────────────────────
TAVILY_API_KEY = "tvly-your-key-here"
GROQ_API_KEY   = "gsk_your-key-here"

tavily      = TavilyClient(api_key="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")
groq_client = Groq(api_key="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")
embedder    = SentenceTransformer("all-MiniLM-L6-v2")

# Try to initialize ChromaDB, if it fails due to permissions, set to None
chroma      = None
collection  = None
try:
    script_dir  = os.path.dirname(os.path.abspath(__file__))
    chroma      = chromadb.PersistentClient(path=os.path.join(script_dir, "chroma_db"))
    try:
        collection  = chroma.get_collection("tourism_cases")
    except Exception as e:
        print(f"WARNING: Could not load chroma collection: {e}")
        collection = None
except Exception as e:
    print(f"WARNING: Could not initialize ChromaDB (permissions issue): {str(e)[:100]}")
    chroma = None
    collection = None

# ── Confidence thresholds ─────────────────────────────────────────────────────
# above 0.75 → use knowledge base only
# 0.40-0.75  → combine knowledge base + web search
# below 0.40 → web search only
HIGH_CONFIDENCE   = 0.75
MEDIUM_CONFIDENCE = 0.40


# ── Layer 1: Knowledge base retrieval ─────────────────────────────────────────

def retrieve_from_kb(complaint_text, issues, top_k=3):
    """Search ChromaDB for most similar case studies."""
    if collection is None:
        return []
    
    issue_names     = [i["issue"] for i in issues]
    query           = f"Tourist complaint: {', '.join(issue_names)}. Review: {complaint_text}"
    query_embedding = embedder.encode(query).tolist()

    results    = collection.query(
        query_embeddings=[query_embedding],
        n_results=top_k
    )

    cases      = []
    best_score = 0.0

    for i in range(len(results["ids"][0])):
        meta       = results["metadatas"][0][i]
        similarity = round(1 - results["distances"][0][i], 3)

        if similarity > best_score:
            best_score = similarity

        cases.append({
            "country":       meta["country"],
            "site":          meta["site"],
            "problem":       meta["problem"],
            "solution":      meta["solution"],
            "strategy_type": meta["strategy_type"],
            "similarity":    similarity,
            "source":        "knowledge_base"
        })

    return cases, best_score


# ── Layer 2/3: Web search ─────────────────────────────────────────────────────

def search_web_for_cases(complaint_text, issues):
    """Search web for real tourism management solutions."""
    issue_names = [i["issue"] for i in issues]
    query = (
        f"tourism site management solution for {', '.join(issue_names[:2])} "
        f"heritage site world best practice case study"
    )

    print(f"    Searching web: {query}")

    try:
        results   = tavily.search(
            query=query,
            search_depth="advanced",
            max_results=5,
            include_answer=True
        )
        web_cases = []

        if results.get("answer"):
            web_cases.append({
                "country":       "Multiple sources",
                "site":          "Web research",
                "problem":       f"Similar to: {', '.join(issue_names)}",
                "solution":      results["answer"],
                "strategy_type": "web_sourced",
                "similarity":    None,
                "source":        "web_search"
            })

        for r in results.get("results", [])[:3]:
            web_cases.append({
                "country":       "Web source",
                "site":          r.get("url", ""),
                "problem":       f"Related to: {', '.join(issue_names)}",
                "solution":      r.get("content", "")[:500],
                "strategy_type": "web_sourced",
                "similarity":    None,
                "source":        "web_search"
            })

        return web_cases

    except Exception as e:
        print(f"    Web search failed: {e}")
        return []


# ── Decision engine ───────────────────────────────────────────────────────────

def decide_layer(best_score):
    """Decide which layer to use based on similarity score."""
    if best_score >= HIGH_CONFIDENCE:
        return "layer_1_kb_only", "HIGH"
    elif best_score >= MEDIUM_CONFIDENCE:
        return "layer_2_hybrid", "MEDIUM"
    else:
        return "layer_3_web_only", "LOW"


# ── LLM generation using Groq ─────────────────────────────────────────────────

def generate_recommendation(complaint_text, issues, cases, confidence_label, layer_used):
    """Generate a recommendation using Groq's free Llama model."""
    issue_names = [i["issue"] for i in issues]

    cases_text = ""
    for i, case in enumerate(cases[:4]):
        sim_str     = f"(similarity: {case['similarity']})" if case["similarity"] else "(from web search)"
        cases_text += f"""
Reference {i+1} — {case['country']}, {case['site']} {sim_str}
Problem they faced: {case['problem']}
Solution they used: {case['solution']}
"""

    if layer_used == "layer_1_kb_only":
        instruction = "The following case studies are highly relevant. Use them as your primary reference."
    elif layer_used == "layer_2_hybrid":
        instruction = "The following references combine knowledge base cases and web research. Synthesize carefully."
    else:
        instruction = "No strong matches found in knowledge base. The following comes from web research. Be cautious and general."

    prompt = f"""You are a tourism management consultant for Sigiriya Rock Fortress, Sri Lanka — a UNESCO World Heritage site.

Visitor complaint:
"{complaint_text}"

Detected problems: {issue_names}

{instruction}

{cases_text}

Write a specific practical recommendation for Sigiriya management. Structure it exactly as:

CORE ISSUE: (one sentence naming the problem)
REFERENCE: (which country approach is most relevant and why)
RECOMMENDATION: (3-4 concrete action steps adapted to Sigiriya)
EXPECTED OUTCOME: (what improvement to expect)

Keep under 250 words. Be direct. Adapt everything to Sri Lanka context."""

    response = groq_client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        max_tokens=500,
        messages=[{"role": "user", "content": prompt}]
    )

    return response.choices[0].message.content


# ── Main pipeline for one review ──────────────────────────────────────────────

def recommend_for_review(review):
    """Full three-layer RAG pipeline for a single review."""

    # Skip positive reviews
    if review["sentiment"] == "positive":
        return {**review, "recommendation": None, "layer_used": None}

    issues = review.get("issues", [])
    if not issues:
        return {**review, "recommendation": None, "layer_used": None}

    complaint = review.get("translated_text", review["text"])
    print(f"\n  Review: {complaint[:70]}...")

    # Step 1: Search knowledge base
    kb_cases, best_score = retrieve_from_kb(complaint, issues)
    print(f"  Best KB similarity score: {best_score}")

    # Step 2: Decide which layer
    layer_used, confidence_label = decide_layer(best_score)
    print(f"  Layer selected: {layer_used} (confidence: {confidence_label})")

    # Step 3: Gather context based on layer
    if layer_used == "layer_1_kb_only":
        all_cases = kb_cases

    elif layer_used == "layer_2_hybrid":
        web_cases = search_web_for_cases(complaint, issues)
        all_cases = kb_cases + web_cases

    else:
        all_cases = search_web_for_cases(complaint, issues)

    # Step 4: Generate recommendation
    recommendation = generate_recommendation(
        complaint, issues, all_cases, confidence_label, layer_used
    )

    return {
        **review,
        "layer_used":       layer_used,
        "confidence_label": confidence_label,
        "best_kb_score":    best_score,
        "cases_used":       all_cases,
        "recommendation":   recommendation
    }


# ── Batch processing ──────────────────────────────────────────────────────────

def process_all_bad_reviews(
    analyzed_file=None,
    output_file=None
):
    import os
    if analyzed_file is None:
        analyzed_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "reviews_analyzed.json")
    if output_file is None:
        output_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "reviews_with_recommendations.json")
    
    with open(analyzed_file, encoding="utf-8") as f:
        reviews = json.load(f)

    bad_reviews = [r for r in reviews if r["sentiment"] in ["negative", "neutral"]]
    print(f"\nFound {len(bad_reviews)} negative/neutral reviews to process.")

    results     = []
    layer_stats = {
        "layer_1_kb_only":  0,
        "layer_2_hybrid":   0,
        "layer_3_web_only": 0
    }

    for i, review in enumerate(bad_reviews):
        print(f"\n[{i+1}/{len(bad_reviews)}]")
        result = recommend_for_review(review)
        results.append(result)

        if result.get("layer_used"):
            layer_stats[result["layer_used"]] += 1

    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    # Print layer statistics — this is your research finding for the viva
    print("\n" + "=" * 50)
    print("LAYER USAGE STATISTICS (your research finding)")
    print("=" * 50)
    total = sum(layer_stats.values())
    for layer, count in layer_stats.items():
        pct = round(count / total * 100, 1) if total > 0 else 0
        print(f"  {layer:25s}: {count} reviews ({pct}%)")

    print(f"\nFull results saved to {output_file}")
    return results, layer_stats


if __name__ == "__main__":
    process_all_bad_reviews()