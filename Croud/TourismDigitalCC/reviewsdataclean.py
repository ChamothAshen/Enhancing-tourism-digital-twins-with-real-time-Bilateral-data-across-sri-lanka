import os
import json
import re

import pandas as pd


def _remove_emojis(text: str) -> str:
	"""Remove common emoji characters from text."""
	# Regex covering most emoji ranges (faces, symbols, flags, etc.).
	# Keep this as a single character class without inline comments.
	emoji_pattern = re.compile(
		"["
		"\U0001F600-\U0001F64F"  # emoticons
		"\U0001F300-\U0001F5FF"  # symbols & pictographs
		"\U0001F680-\U0001F6FF"  # transport & map symbols
		"\U0001F700-\U0001F77F"  # alchemical symbols
		"\U0001F780-\U0001F7FF"  # geometric shapes extended
		"\U0001F800-\U0001F8FF"  # supplemental arrows-C
		"\U0001F900-\U0001F9FF"  # supplemental symbols & pictographs
		"\U0001FA00-\U0001FA6F"  # chess symbols, etc.
		"\U0001FA70-\U0001FAFF"  # symbols & pictographs extended-A
		"\u2600-\u26FF"          # misc symbols
		"\u2700-\u27BF"          # dingbats
		"]",
		flags=re.UNICODE,
	)
	return emoji_pattern.sub("", text)


def clean_google_reviews(json_path="google_reviews.json", output_csv="sigiriya_negative_reviews_clean.csv"):
	"""Clean Google reviews JSON for sentiment analysis.

	- Loads reviews from `json_path` and flattens nested fields.
	- Uses translated text when available, otherwise original text.
	- Drops rows with missing text or stars.
	- Strips whitespace and removes duplicate texts.
	- Keeps only: review_text, rating, date.
	- Writes cleaned data to `output_csv`.
	"""

	if not os.path.exists(json_path):
		print(f"JSON file not found: {json_path}")
		return

	# Load raw JSON as list/dict, then normalize
	with open(json_path, "r", encoding="utf-8") as f:
		data = json.load(f)

	df = pd.json_normalize(data)

	# Decide which text to use: prefer translated text when present, otherwise original text
	if "textTranslated" in df.columns:
		translated = df["textTranslated"].fillna("").astype(str)
		original = df["text"].fillna("").astype(str)
		combined_text = translated.where(translated.str.strip().ne(""), original)
	else:
		combined_text = df["text"].fillna("").astype(str)

	# Strip emojis and whitespace from the chosen text
	combined_text = combined_text.apply(_remove_emojis)
	df["clean_text"] = combined_text.str.strip()

	# Drop rows without clean text or stars
	required_cols = ["clean_text", "stars"]
	existing_required = [c for c in required_cols if c in df.columns]
	if len(existing_required) < 2:
		print("JSON does not contain both text (or translated text) and 'stars' fields; cannot clean for sentiment.")
		return

	df = df.dropna(subset=existing_required)
	df = df[df["clean_text"].str.strip().ne("")]

	# Remove exact duplicate texts
	df = df.drop_duplicates(subset=["clean_text"])

	# Build final DataFrame: review_text, rating, date
	date_col = "publishedAtDate" if "publishedAtDate" in df.columns else None

	cols = {
		"clean_text": "review_text",
		"stars": "rating",
	}

	if date_col:
		cols[date_col] = "date"

	final_cols_in_source = list(cols.keys())
	final_df = df[final_cols_in_source].rename(columns=cols)

	# Parse and sort by date if available
	if "date" in final_df.columns:
		final_df["date"] = pd.to_datetime(final_df["date"], errors="coerce")
		final_df = final_df.sort_values("date", ascending=False)

	# Add a simple unique review ID to help identify each row
	final_df = final_df.reset_index(drop=True)
	final_df.insert(0, "review_id", final_df.index + 1)

	final_df.to_csv(output_csv, index=False)

	print(f"Cleaned reviews saved to: {output_csv}")
	print(f"Total cleaned reviews: {len(final_df)}")


if __name__ == "__main__":
	# When run as a script from this folder, clean the default JSON
	base_dir = os.path.dirname(os.path.abspath(__file__))
	json_path = os.path.join(base_dir, "google_reviews.json")
	output_path = os.path.join(base_dir, "sigiriya_negative_reviews_clean.csv")
	clean_google_reviews(json_path=json_path, output_csv=output_path)

