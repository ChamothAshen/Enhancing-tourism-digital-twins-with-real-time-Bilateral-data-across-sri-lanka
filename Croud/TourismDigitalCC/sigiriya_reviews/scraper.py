# scraper.py
import asyncio
import json
import os
from datetime import datetime, timedelta
from playwright.async_api import async_playwright

SCRIPT_DIR    = os.path.dirname(os.path.abspath(__file__))
SEEN_IDS_FILE = os.path.join(SCRIPT_DIR, "seen_ids.json")
RAW_FILE      = os.path.join(SCRIPT_DIR, "reviews_raw.json")
CUTOFF_DATE   = datetime.now() - timedelta(days=730)


def load_seen_ids():
    try:
        with open(SEEN_IDS_FILE, encoding="utf-8") as f:
            return set(json.load(f))
    except FileNotFoundError:
        return set()


def save_seen_ids(seen_ids):
    with open(SEEN_IDS_FILE, "w", encoding="utf-8") as f:
        json.dump(list(seen_ids), f)


def load_existing_reviews():
    try:
        with open(RAW_FILE, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return []


def save_all_reviews(reviews):
    with open(RAW_FILE, "w", encoding="utf-8") as f:
        json.dump(reviews, f, ensure_ascii=False, indent=2)


def is_within_2_years(time_str):
    if not time_str:
        return True
    time_str = time_str.lower().strip()
    now = datetime.now()
    try:
        if any(x in time_str for x in ["just now", "minute", "hour"]):
            return True
        elif "day" in time_str:
            days = int(''.join(filter(str.isdigit, time_str)) or 1)
            return now - timedelta(days=days) >= CUTOFF_DATE
        elif "week" in time_str:
            weeks = int(''.join(filter(str.isdigit, time_str)) or 1)
            return now - timedelta(weeks=weeks) >= CUTOFF_DATE
        elif "month" in time_str:
            months = int(''.join(filter(str.isdigit, time_str)) or 1)
            return now - timedelta(days=months * 30) >= CUTOFF_DATE
        elif "year" in time_str:
            years = int(''.join(filter(str.isdigit, time_str)) or 1)
            return now - timedelta(days=years * 365) >= CUTOFF_DATE
    except Exception:
        pass
    return True


async def dismiss_popups(page):
    popup_selectors = [
        'button:has-text("Accept all")',
        'button:has-text("Reject all")',
        'button:has-text("Accept")',
        'button:has-text("I agree")',
        'button:has-text("No thanks")',
        'button:has-text("Dismiss")',
        'button:has-text("Got it")',
        '[aria-label="Close"]',
        'button:has-text("Close")',
    ]
    for selector in popup_selectors:
        try:
            btn = page.locator(selector).first
            if await btn.is_visible(timeout=1000):
                await btn.click()
                await page.wait_for_timeout(500)
        except Exception:
            continue


async def open_reviews_tab(page):
    print("  Opening Google Maps...")
    await page.goto(
        "https://www.google.com/maps",
        wait_until="domcontentloaded",
        timeout=60000
    )
    await page.wait_for_timeout(4000)
    await dismiss_popups(page)

    print("  Searching Sigiriya Rock Fortress...")
    await page.mouse.click(240, 36)
    await page.wait_for_timeout(800)
    await page.keyboard.press("Control+a")
    await page.keyboard.press("Delete")
    await page.keyboard.type("Sigiriya Rock Fortress", delay=100)
    await page.wait_for_timeout(3000)

    clicked = False
    try:
        items = page.locator('[role="option"], [role="listitem"]')
        count = await items.count()
        for i in range(count):
            item = items.nth(i)
            text = (await item.inner_text()).strip()
            if "\n" in text and "Sigiriya" in text:
                await item.click()
                clicked = True
                try:
                    await page.wait_for_timeout(5000)
                except:
                    pass
                break
    except Exception:
        pass

    if not clicked:
        await page.keyboard.press("Enter")
        try:
            await page.wait_for_timeout(5000)
        except:
            pass

    for attempt in range(10):
        try:
            tab_texts = await page.evaluate("""
                () => Array.from(document.querySelectorAll('[role="tab"]'))
                     .map(t => t.textContent.trim())
            """)
            if "Reviews" in tab_texts:
                break
        except:
            pass
        try:
            await page.wait_for_timeout(1000)
        except:
            if attempt > 5:
                break

    try:
        tab = page.get_by_role("tab", name="Reviews")
        await tab.wait_for(timeout=10000)
        await tab.click()
        try:
            await page.wait_for_timeout(2000)
        except:
            pass
        print("  Reviews tab opened")
        return True
    except Exception as e:
        print(f"  Tab click failed: {str(e)[:100]}")

    try:
        done = await page.evaluate("""
            () => {
                for (const t of document.querySelectorAll('[role="tab"]')) {
                    if (t.textContent.trim() === 'Reviews') {
                        t.click();
                        return true;
                    }
                }
                return false;
        """)
        if done:
            try:
                await page.wait_for_timeout(2000)
            except:
                pass
            print("  Reviews tab opened (via JS click)")
            return True
    except Exception as e:
        print(f"  JS click failed: {str(e)[:100]}")

    return False


async def sort_by_newest(page):
    """
    Sort reviews by Newest — tries every possible method.
    This is critical so new reviews appear at the top.
    """
    print("  Sorting by Newest...")
    await page.wait_for_timeout(1000)

    # Method 1: click Sort button then Newest
    try:
        sort_btn = page.locator('button[data-value="Sort"]')
        await sort_btn.wait_for(timeout=5000)
        await sort_btn.click()
        await page.wait_for_timeout(1500)
        await page.screenshot(path=os.path.join(SCRIPT_DIR, "sort_menu.png"))

        # Try clicking Newest from menu
        newest = page.get_by_text("Newest", exact=True)
        await newest.wait_for(timeout=3000)
        await newest.click()
        await page.wait_for_timeout(2000)
        print("  Sorted by Newest (method 1)")
        return True
    except Exception:
        pass

    # Method 2: JavaScript — open sort menu and click Newest
    try:
        await page.evaluate("""
            () => {
                const btn = document.querySelector('[data-value="Sort"]');
                if (btn) btn.click();
            }
        """)
        await page.wait_for_timeout(1500)

        clicked = await page.evaluate("""
            () => {
                const all = document.querySelectorAll(
                    '[role="menuitemradio"], [role="option"], [role="menuitem"], li'
                );
                for (const el of all) {
                    if (el.textContent.trim() === 'Newest') {
                        el.click();
                        return true;
                    }
                }
                return false;
            }
        """)
        if clicked:
            await page.wait_for_timeout(2000)
            print("  Sorted by Newest (method 2 JS)")
            return True
    except Exception:
        pass

    # Method 3: keyboard navigation — Tab to sort, Enter, arrow to Newest
    try:
        sort_btn = page.locator('button[data-value="Sort"]')
        await sort_btn.click(timeout=3000)
        await page.wait_for_timeout(1000)
        # Press ArrowDown to navigate to Newest (second option)
        await page.keyboard.press("ArrowDown")
        await page.wait_for_timeout(300)
        await page.keyboard.press("Enter")
        await page.wait_for_timeout(2000)
        print("  Sorted by Newest (method 3 keyboard)")
        return True
    except Exception:
        pass

    print("  Could not sort by Newest — check sort_menu.png")
    return False


async def extract_visible_reviews(page):
    try:
        await page.evaluate("""
            () => document.querySelectorAll('button').forEach(b => {
                if (b.textContent.includes('See more') ||
                    (b.getAttribute('aria-label') || '').includes('See more'))
                    b.click();
            })
        """)
        await page.wait_for_timeout(500)
    except Exception:
        pass

    return await page.evaluate("""
        () => {
            const results = [];
            document.querySelectorAll('[data-review-id]').forEach(card => {
                try {
                    const id = card.getAttribute('data-review-id');
                    if (!id) return;

                    let rating = 0;
                    const star = card.querySelector('[role="img"][aria-label*="star"]');
                    if (star) {
                        const m = star.getAttribute('aria-label').match(/\\d/);
                        if (m) rating = parseInt(m[0]);
                    }

                    let text = '', maxLen = 0;
                    card.querySelectorAll('span').forEach(s => {
                        const t = (s.innerText || s.textContent || '').trim();
                        if (t.length > maxLen && t.length > 15 &&
                            !t.includes('See more') && !t.includes('Like') &&
                            !t.includes('Share')) {
                            maxLen = t.length; text = t;
                        }
                    });

                    let author = '';
                    for (const d of card.querySelectorAll('div')) {
                        const t = (d.innerText || '').trim();
                        if (t.length > 2 && t.length < 60 &&
                            !t.includes('\\n') && !t.includes('ago') &&
                            !t.match(/^\\d/)) { author = t; break; }
                    }

                    let time = '';
                    card.querySelectorAll('span').forEach(s => {
                        const t = (s.innerText || '').trim();
                        if (t.match(/(ago|month|year|week|day)/i) && t.length < 30)
                            time = t;
                    });

                    if (id && text) results.push({ id, rating, text, author, time });
                } catch(e) {}
            });
            return results;
        }
    """)


# ═══════════════════════════════════════════════════════
# MODE 1 — INITIAL SCRAPE
# ═══════════════════════════════════════════════════════

async def initial_scrape(headless=False):
    print("\n" + "="*50)
    print("INITIAL SCRAPE — collecting all reviews from past 2 years")
    print("="*50)

    async with async_playwright() as p:
        browser = await p.firefox.launch(
            headless=headless
        )
        context = await browser.new_context(
            locale="en-US",
            viewport={"width": 1280, "height": 900},
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:120.0) Gecko/20100101 Firefox/120.0"
        )
        page = await context.new_page()

        found = await open_reviews_tab(page)
        if not found:
            print("Could not open reviews tab.")
            await browser.close()
            return []

        await sort_by_newest(page)

        collected   = {}
        stall_count = 0
        stop        = False

        await page.mouse.move(400, 400)

        while stall_count < 10 and not stop:
            batch    = await extract_visible_reviews(page)
            prev_len = len(collected)

            for r in batch:
                if r["id"] in collected:
                    continue
                if not is_within_2_years(r["time"]):
                    print(f"  Reached old review ({r['time']}) — stopping")
                    stop = True
                    break
                r["scraped_at"] = datetime.now().isoformat()
                collected[r["id"]] = r

            print(f"  Collected {len(collected)} reviews...")

            if len(collected) > prev_len:
                stall_count = 0
            else:
                stall_count += 1

            if not stop:
                for _ in range(5):
                    await page.mouse.wheel(0, 500)
                    await page.wait_for_timeout(300)
                await page.wait_for_timeout(2000)

        await browser.close()

    all_reviews = list(collected.values())
    save_all_reviews(all_reviews)

    seen_ids = set(r["id"] for r in all_reviews)
    save_seen_ids(seen_ids)

    print(f"\nInitial scrape complete: {len(all_reviews)} reviews saved")
    return all_reviews


# ═══════════════════════════════════════════════════════
# MODE 2 — BACKGROUND CHECK every 2 minutes
# ═══════════════════════════════════════════════════════

async def check_for_new_reviews(headless=True):
    seen_ids       = load_seen_ids()
    existing       = load_existing_reviews()
    existing_by_id = {r["id"]: r for r in existing}

    print(f"  Known reviews: {len(seen_ids)}")

    async with async_playwright() as p:
        browser = await p.firefox.launch(
            headless=headless
        )
        context = await browser.new_context(
            locale="en-US",
            viewport={"width": 1280, "height": 900},
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:120.0) Gecko/20100101 Firefox/120.0"
        )
        page = await context.new_page()

        found = await open_reviews_tab(page)
        if not found:
            print("  Could not open reviews tab.")
            await browser.close()
            return []

        # CRITICAL — sort by Newest so new reviews are at top
        sorted_ok = await sort_by_newest(page)
        if not sorted_ok:
            print("  WARNING: Not sorted by Newest — may miss new reviews!")

        # Take screenshot so you can verify it's sorted correctly
        await page.screenshot(path=os.path.join(SCRIPT_DIR, "check_screenshot.png"))
        print("  Saved check_screenshot.png — verify it shows Newest sort")

        # Get top 20 reviews — no scrolling needed
        top_reviews = await extract_visible_reviews(page)
        print(f"  Checked top {len(top_reviews)} reviews")

        # Print what we found for debugging
        for r in top_reviews[:5]:
            status = "NEW" if r["id"] not in seen_ids else "seen"
            print(f"    [{status}] {r['time']} — {r['text'][:50]}")

        await browser.close()

    # Find genuinely new ones
    new_reviews = [
        r for r in top_reviews
        if r["id"] not in seen_ids and is_within_2_years(r["time"])
    ]

    if not new_reviews:
        print("  No new reviews.")
        return []

    print(f"  {len(new_reviews)} NEW review(s) detected!")

    for r in new_reviews:
        r["scraped_at"]         = datetime.now().isoformat()
        existing_by_id[r["id"]] = r

    save_all_reviews(list(existing_by_id.values()))

    seen_ids.update(r["id"] for r in top_reviews)
    save_seen_ids(seen_ids)

    return new_reviews