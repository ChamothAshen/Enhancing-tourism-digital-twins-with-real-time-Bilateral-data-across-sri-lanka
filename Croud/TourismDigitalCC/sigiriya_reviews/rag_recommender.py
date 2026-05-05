# rag_recommender.py
import json
import os
import time
import chromadb
from sentence_transformers import SentenceTransformer
from tavily import TavilyClient
from groq import Groq
from dotenv import load_dotenv

load_dotenv()

TAVILY_API_KEY = os.getenv("TAVILY_API_KEY")
GROQ_API_KEY   = os.getenv("GROQ_API_KEY")
GROQ_MODEL     = os.getenv("GROQ_MODEL", "llama-3.1-8b-instant")

tavily   = TavilyClient(api_key=TAVILY_API_KEY)
groq_client = Groq(api_key=GROQ_API_KEY)

embedder   = SentenceTransformer("all-MiniLM-L6-v2")
chroma     = chromadb.PersistentClient(path="./chroma_db")
collection = chroma.get_collection("tourism_cases")

HIGH_CONFIDENCE   = 0.75
MEDIUM_CONFIDENCE = 0.40


# ── Retrieval ─────────────────────────────────────────────────────────────────

def retrieve_from_kb(complaint_text, issues, top_k=3):
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


def search_web_for_cases(complaint_text, issues):
    issue_names = [i["issue"] for i in issues]
    query = (
        f"tourism heritage site management solution "
        f"{', '.join(issue_names[:2])} best practice case study"
    )

    print(f"    Web search: {query[:60]}...")

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
                "country":   "Multiple sources",
                "site":      "Web research",
                "problem":   f"Similar to: {', '.join(issue_names)}",
                "solution":  results["answer"],
                "similarity": None,
                "source":    "web_search"
            })

        for r in results.get("results", [])[:3]:
            web_cases.append({
                "country":   "Web source",
                "site":      r.get("url", ""),
                "problem":   f"Related to: {', '.join(issue_names)}",
                "solution":  r.get("content", "")[:500],
                "similarity": None,
                "source":    "web_search"
            })

        return web_cases

    except Exception as e:
        print(f"    Web search failed: {e}")
        return []


def decide_layer(best_score):
    if best_score >= HIGH_CONFIDENCE:
        return "layer_1_kb_only", "HIGH"
    elif best_score >= MEDIUM_CONFIDENCE:
        return "layer_2_hybrid", "MEDIUM"
    else:
        return "layer_3_web_only", "LOW"


# ── Generation ────────────────────────────────────────────────────────────────

def generate_recommendation(complaint_text, issues, cases, confidence_label, layer_used):
    issue_names = [i["issue"] for i in issues]

    # Format case studies
    cases_text = ""
    for i, case in enumerate(cases[:4]):
        sim_str = (
            f"(similarity: {case['similarity']})"
            if case.get("similarity") else "(from web search)"
        )
        cases_text += f"""
Example {i+1} — {case['country']}, {case['site']} {sim_str}
Problem: {case['problem']}
Solution: {case['solution']}
"""

    prompt = f"""You are a tourism management assistant helping officers 
at Sigiriya Rock Fortress, Sri Lanka (UNESCO World Heritage Site).

Important:
- Use the case studies only as inspiration.
- Convert every idea into a Sri Lanka-implementable action.
- Explain it in simple, human language.
- Prefer low-cost actions using current staff, signage, queue control, simple booking rules, local transport coordination, and site management changes.
- Do NOT recommend expensive systems unless there is a realistic low-cost version for Sri Lanka.
- The final solution must feel like advice for a site manager in Sri Lanka, not a global report.

A visitor left this complaint:
"{complaint_text}"

Main problems: {issue_names}

Real examples from other countries that solved similar problems:
{cases_text}

Write a clear practical solution for the Sigiriya site officer.
First say the global idea in one short sentence.
Then explain exactly how that idea can be done at Sigiriya in Sri Lanka.
Use this exact format:

🔴 PROBLEM:
[One short sentence — what is the visitor complaining about]

🌍 WHAT OTHER COUNTRIES DID:
[Pick the most relevant example above. Say which country and site.
Explain what they did and what result they got in 1-2 simple sentences.
Keep this part short.]

✅ WHAT SIGIRIYA SHOULD DO:

THIS WEEK:
- [very simple action 1 that Sigiriya staff can start now]
- [very simple action 2 that Sigiriya staff can start now]

THIS MONTH:
- [action 1 that can be done in 30 days with local staff/resources]
- [action 2 that can be done in 30 days with local staff/resources]

IN 3 MONTHS:
- [bigger action based on the global idea, adapted to Sri Lanka]
- [how to do it with Sri Lankan staff, rules, and budget limits]

SRI LANKA IMPLEMENTATION NOTES:
- Mention the local actor who should do it (site staff, SLTDA, police, ticket counter, guides, tuk-tuk area, etc.)
- Mention the lowest-cost way to start
- Mention how to measure success at Sigiriya
- Mention the exact place at Sigiriya if possible
- Keep sentences short and easy to understand

Rules:
- Simple English only
- Specific to Sigiriya Sri Lanka
- Practical and realistic
- Maximum 250 words
- No complicated academic language"""

    # Retry up to 3 times if Groq fails
    for attempt in range(3):
        try:
            response = groq_client.chat.completions.create(
                model=GROQ_MODEL,
                temperature=0.4,
                max_tokens=700,
                messages=[
                    {
                        "role": "system",
                        "content": "You are a practical tourism operations advisor. Give clear, realistic actions."
                    },
                    {
                        "role": "user",
                        "content": prompt
                    }
                ],
            )
            return response.choices[0].message.content.strip()
        except Exception as e:
            print(f"    Groq attempt {attempt+1} failed: {e}")
            if attempt < 2:
                time.sleep(5)

    return "Could not generate recommendation — please try again."


# ── Main pipeline ─────────────────────────────────────────────────────────────

def recommend_for_review(review):
    """Full RAG pipeline for one review."""

    # Skip positive reviews
    if review.get("sentiment") == "positive":
        return {**review, "recommendation": None, "layer_used": None}

    issues = review.get("issues", [])
    if not issues:
        return {**review, "recommendation": None, "layer_used": None}

    complaint = review.get("translated_text", review.get("text", ""))
    print(f"\n  Review: {complaint[:70]}...")

    # Step 1: Search knowledge base
    kb_cases, best_score = retrieve_from_kb(complaint, issues)
    print(f"  KB similarity: {best_score}")

    # Step 2: Decide layer
    layer_used, confidence_label = decide_layer(best_score)
    print(f"  Layer: {layer_used} ({confidence_label})")

    # Step 3: Gather context
    if layer_used == "layer_1_kb_only":
        all_cases = kb_cases
    elif layer_used == "layer_2_hybrid":
        all_cases = kb_cases + search_web_for_cases(complaint, issues)
    else:
        all_cases = search_web_for_cases(complaint, issues)

    # Step 4: Generate with Groq
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


def process_all_bad_reviews(
    analyzed_file="reviews_analyzed.json",
    output_file="reviews_with_recommendations.json",
    reprocess_failed=True
):
    with open(analyzed_file, encoding="utf-8") as f:
        reviews = json.load(f)

    # Load already processed to skip them
    already_done = set()
    results      = []
    try:
        with open(output_file, encoding="utf-8") as f:
            existing     = json.load(f)
            if reprocess_failed:
                already_done = set(
                    r["id"]
                    for r in existing
                    if r.get("recommendation")
                    and not str(r.get("recommendation", "")).lower().startswith("could not generate recommendation")
                )
            else:
                already_done = set(r["id"] for r in existing if r.get("recommendation"))
            results      = existing
        print(f"  Already processed: {len(already_done)} reviews")
    except FileNotFoundError:
        pass

    # Only process negative/neutral with issues that haven't been done yet
    bad_reviews = [
        r for r in reviews
        if r.get("sentiment") in ["negative", "neutral"]
        and r.get("issues")
        and r["id"] not in already_done
    ]

    print(f"  Reviews left to process: {len(bad_reviews)}")

    layer_stats = {
        "layer_1_kb_only":  0,
        "layer_2_hybrid":   0,
        "layer_3_web_only": 0
    }

    for i, review in enumerate(bad_reviews):
        print(f"\n[{i+1}/{len(bad_reviews)}]")
        try:
            result = recommend_for_review(review)
            results.append(result)

            if result.get("layer_used"):
                layer_stats[result["layer_used"]] += 1

            # Save after every single review — never lose progress
            with open(output_file, "w", encoding="utf-8") as f:
                json.dump(results, f, ensure_ascii=False, indent=2)

        except Exception as e:
            print(f"  Error: {e}")
            if "429" in str(e) or "quota" in str(e).lower():
                print("  Rate limit hit. Progress saved. Run again to continue.")
                break
            continue

    print(f"\n{'='*50}")
    print("LAYER USAGE STATISTICS")
    print("="*50)
    total = sum(layer_stats.values())
    for layer, count in layer_stats.items():
        pct = round(count / total * 100, 1) if total > 0 else 0
        print(f"  {layer:25s}: {count} ({pct}%)")

    return results, layer_stats