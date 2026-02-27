"""
Test MongoDB connection
"""
import os
from dotenv import load_dotenv
from pymongo import MongoClient
import certifi

load_dotenv()

MONGODB_URI = os.getenv("MONGODB_URI", "mongodb://localhost:27017")
MONGODB_DB_NAME = os.getenv("MONGODB_DB_NAME", "sigiriya_tourism")

print(f"Testing MongoDB connection...")
print(f"URI: {MONGODB_URI[:50]}...")
print(f"Database: {MONGODB_DB_NAME}")
print()

try:
    # Try to connect with a short timeout and SSL certificates
    client = MongoClient(
        MONGODB_URI, 
        serverSelectionTimeoutMS=10000,
        tlsCAFile=certifi.where()
    )
    
    # Test the connection
    client.admin.command('ping')
    print("✅ Successfully connected to MongoDB!")
    
    # List databases
    dbs = client.list_database_names()
    print(f"✅ Available databases: {dbs}")
    
    # Test database access
    db = client[MONGODB_DB_NAME]
    collections = db.list_collection_names()
    print(f"✅ Collections in '{MONGODB_DB_NAME}': {collections if collections else 'None (new database)'}")
    
    client.close()
    print("\n✅ MongoDB connection test PASSED!")
    
except Exception as e:
    print(f"\n❌ MongoDB connection test FAILED!")
    print(f"Error: {e}")
    print("\nPossible issues:")
    print("1. Check your internet connection")
    print("2. Verify MongoDB Atlas cluster is active")
    print("3. Check if IP address is whitelisted in MongoDB Atlas")
    print("4. Verify credentials in .env file")
