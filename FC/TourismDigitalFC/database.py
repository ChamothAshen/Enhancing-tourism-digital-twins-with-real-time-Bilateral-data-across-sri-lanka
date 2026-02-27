from motor.motor_asyncio import AsyncIOMotorClient
from pymongo import MongoClient
import os
from dotenv import load_dotenv
import certifi

load_dotenv()

MONGODB_URI = os.getenv("MONGODB_URI", "mongodb://localhost:27017")
MONGODB_DB_NAME = os.getenv("MONGODB_DB_NAME", "sigiriya_tourism")

# Async client for FastAPI
motor_client: AsyncIOMotorClient = None
database = None

# Sync client for initial setup (lazy initialization)
sync_client = None
sync_db = None


async def connect_to_mongo():
    """Connect to MongoDB on startup"""
    global motor_client, database, sync_client, sync_db
    
    try:
        # Use certifi for SSL certificate verification (fixes macOS SSL issues)
        motor_client = AsyncIOMotorClient(
            MONGODB_URI, 
            serverSelectionTimeoutMS=5000,
            tlsCAFile=certifi.where()
        )
        database = motor_client[MONGODB_DB_NAME]
        
        # Test the connection
        await motor_client.admin.command('ping')
        print(f"✓ Connected to MongoDB: {MONGODB_DB_NAME}")
        
        # Initialize sync client if needed
        sync_client = MongoClient(
            MONGODB_URI, 
            serverSelectionTimeoutMS=5000,
            tlsCAFile=certifi.where()
        )
        sync_db = sync_client[MONGODB_DB_NAME]
        
    except Exception as e:
        print(f"⚠️  MongoDB connection failed: {e}")
        print(f"⚠️  Server will run but authentication features will not work")
        print(f"⚠️  Check your internet connection and MongoDB URI")
        # Set to None to allow server to start without MongoDB
        motor_client = None
        database = None


async def close_mongo_connection():
    """Close MongoDB connection on shutdown"""
    global motor_client, sync_client
    if motor_client:
        motor_client.close()
        print("✓ MongoDB connection closed")
    if sync_client:
        sync_client.close()


def get_database():
    """Get database instance"""
    if database is None:
        raise Exception("MongoDB not connected. Please check your connection.")
    return database