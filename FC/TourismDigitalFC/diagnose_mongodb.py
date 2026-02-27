"""
Detailed MongoDB Connection Diagnostic
"""
import os
from dotenv import load_dotenv
import socket
import dns.resolver

load_dotenv()

MONGODB_URI = os.getenv("MONGODB_URI", "")

print("=" * 70)
print("MongoDB Connection Diagnostic")
print("=" * 70)

# Extract cluster hostname
if "mongodb+srv://" in MONGODB_URI:
    # Extract hostname from mongodb+srv:// URL
    parts = MONGODB_URI.split("@")
    if len(parts) > 1:
        cluster_host = parts[1].split("/")[0].split("?")[0]
        print(f"\n✓ Connection Type: mongodb+srv:// (DNS SRV)")
        print(f"✓ Cluster Host: {cluster_host}")
        
        # Try DNS SRV lookup
        print(f"\n🔍 Testing DNS SRV lookup for: _mongodb._tcp.{cluster_host}")
        try:
            answers = dns.resolver.resolve(f"_mongodb._tcp.{cluster_host}", "SRV")
            print(f"✅ DNS SRV Records Found:")
            for rdata in answers:
                print(f"   - {rdata.target} (Priority: {rdata.priority}, Port: {rdata.port})")
        except dns.resolver.NXDOMAIN:
            print(f"❌ DNS SRV record does not exist!")
            print(f"\n💡 This means:")
            print(f"   1. The MongoDB cluster may have been deleted")
            print(f"   2. The cluster URL might be incorrect")
            print(f"   3. The cluster may not be fully provisioned yet")
        except Exception as e:
            print(f"❌ DNS SRV lookup failed: {e}")
        
        # Try regular DNS lookup
        print(f"\n🔍 Testing regular DNS lookup for: {cluster_host}")
        try:
            ip = socket.gethostbyname(cluster_host)
            print(f"✅ Host resolves to: {ip}")
        except socket.gaierror:
            print(f"❌ Host does not resolve to an IP address")
        except Exception as e:
            print(f"❌ DNS lookup failed: {e}")
        
        # Try alternative standard connection format
        print(f"\n📋 Alternative Connection Methods:")
        print(f"   If SRV doesn't work, try standard connection format:")
        print(f"   mongodb://username:password@host1:27017,host2:27017,host3:27017/database?options")
        
print("\n" + "=" * 70)
print("Recommendations:")
print("=" * 70)
print("""
1. LOGIN TO MONGODB ATLAS: https://cloud.mongodb.com/
   - Check if your cluster exists and is running
   - Verify the cluster name matches 'cluster0'

2. GET FRESH CONNECTION STRING:
   - Click 'Connect' on your cluster
   - Choose 'Connect your application'
   - Copy the FULL connection string
   - Make sure it includes your password

3. CHECK NETWORK ACCESS:
   - Go to 'Network Access' in MongoDB Atlas
   - Click 'Add IP Address'
   - Select 'Allow Access from Anywhere' (for testing)

4. VERIFY CREDENTIALS:
   - Username: dinusha_nawarathne
   - Password: Check if it's correct in MongoDB Atlas

5. CREATE NEW CLUSTER (if needed):
   - If cluster was deleted, create a new free tier cluster
   - Get the new connection string
   - Update .env file
""")
print("=" * 70)
