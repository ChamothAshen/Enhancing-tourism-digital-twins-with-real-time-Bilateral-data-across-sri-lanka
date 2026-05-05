# test_scroll.py  — run this separately to debug scrolling
import asyncio
from playwright.async_api import async_playwright

async def test():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=False, args=["--lang=en-US"])
        context = await browser.new_context(locale="en-US", viewport={"width": 1280, "height": 900})
        page    = await context.new_page()

        await page.goto("https://www.google.com/maps", wait_until="domcontentloaded")
        await page.wait_for_timeout(4000)

        print("Please manually:")
        print("1. Search Sigiriya Rock Fortress")
        print("2. Click on it")
        print("3. Click Reviews tab")
        print("4. Press ENTER here")
        input("Press ENTER when reviews are visible...")

        # Count current reviews
        count1 = await page.locator('[data-review-id]').count()
        print(f"Reviews before scroll: {count1}")

        # Try scrolling every possible container
        scroll_targets = [
            'div[role="feed"]',
            'div[role="main"]',
            'div[aria-label*="review"]',
            'div[aria-label*="Review"]',
            '.m6QErb',
            '.DxyBCb',
            '.lXJj5c',
        ]

        for selector in scroll_targets:
            try:
                el = page.locator(selector).first
                if await el.count() > 0:
                    box = await el.bounding_box()
                    if box:
                        print(f"Found: {selector} at {box}")
                        # Scroll it
                        await el.evaluate("el => el.scrollBy(0, 3000)")
                        await page.wait_for_timeout(2000)
                        count2 = await page.locator('[data-review-id]').count()
                        print(f"Reviews after scrolling {selector}: {count2}")
                        if count2 > count1:
                            print(f"✓ THIS WORKS: {selector}")
                            break
            except Exception as e:
                print(f"  {selector} failed: {e}")

        # Also try mouse wheel scroll on center of page
        print("\nTrying mouse wheel scroll...")
        await page.mouse.move(400, 400)
        for i in range(10):
            await page.mouse.wheel(0, 500)
            await page.wait_for_timeout(500)

        count3 = await page.locator('[data-review-id]').count()
        print(f"Reviews after mouse wheel: {count3}")

        input("Press ENTER to close...")
        await browser.close()

asyncio.run(test())