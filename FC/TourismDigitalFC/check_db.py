"""
Check MongoDB data
"""
import os
from dotenv import load_dotenv
from pymongo import MongoClient
import certifi

load_dotenv()

MONGODB_URI = os.getenv("MONGODB_URI")
MONGODB_DB_NAME = os.getenv("MONGODB_DB_NAME", "sigiriya_tourism")

try:
    client = MongoClient(MONGODB_URI, tlsCAFile=certifi.where())
    db = client[MONGODB_DB_NAME]
    
    print("=" * 70)
    print("MongoDB Database Contents")
    print("=" * 70)
    
    # List all collections
    collections = db.list_collection_names()
    print(f"\n✓ Collections: {collections}\n")
    
    # Check admins collection
    if 'admins' in collections:
        admins = list(db.admins.find({}, {'hashed_password': 0}))  # Exclude password
        print(f"✓ Admins Collection ({len(admins)} users):")
        for i, admin in enumerate(admins, 1):
            print(f"  {i}. Name: {admin.get('name')}")
            print(f"     Email: {admin.get('email')}")
            print(f"     Phone: {admin.get('phone')}")
            print(f"     Created: {admin.get('created_at')}")
            print(f"     ID: {admin.get('_id')}")
            print()
    
    print("=" * 70)
    print("✅ MongoDB working correctly!")
    print("=" * 70)
    
    client.close()
    
except Exception as e:
    print(f"❌ Error: {e}")
