#!/usr/bin/env python3
"""
MQTT Monitor - Listen to all medicine box messages
Run this to see real-time MQTT updates from your ESP32
"""

import paho.mqtt.client as mqtt
import json
from datetime import datetime

MQTT_BROKER = "34.19.178.165"
MQTT_PORT = 1883
MQTT_TOPIC = "medicinebox/#"  # Subscribe to all medicine box topics

def on_connect(client, userdata, flags, rc):
    """Callback when connected to MQTT broker"""
    if rc == 0:
        print("=" * 60)
        print("✅ Connected to MQTT Broker!")
        print(f"📡 Broker: {MQTT_BROKER}:{MQTT_PORT}")
        print(f"📬 Subscribed to: {MQTT_TOPIC}")
        print("=" * 60)
        print("\n⏳ Waiting for messages from ESP32...\n")
        client.subscribe(MQTT_TOPIC)
    else:
        print(f"❌ Failed to connect, return code {rc}")

def on_message(client, userdata, msg):
    """Callback when message is received"""
    timestamp = datetime.now().strftime("%H:%M:%S")
    topic = msg.topic
    
    try:
        # Try to parse as JSON
        payload = msg.payload.decode()
        data = json.loads(payload)
        
        # Pretty print the message
        print(f"\n{'=' * 60}")
        print(f"🕐 Time: {timestamp}")
        print(f"📨 Topic: {topic}")
        print(f"📦 Data:")
        for key, value in data.items():
            print(f"   {key}: {value}")
        
        # Highlight important info
        if data.get('taken') == True:
            print("✅ STATUS: Medicine TAKEN ✅")
        elif data.get('taken') == False:
            print("⚠️  STATUS: Medicine NOT taken")
        
        print(f"{'=' * 60}\n")
        
    except json.JSONDecodeError:
        # Not JSON, just print raw
        print(f"\n[{timestamp}] {topic}: {msg.payload.decode()}\n")

def on_disconnect(client, userdata, rc):
    """Callback when disconnected"""
    print(f"\n⚠️  Disconnected from MQTT broker (code: {rc})")

# Create MQTT client
print("\n🚀 Starting MQTT Monitor...")
client = mqtt.Client("MQTTMonitor")
client.on_connect = on_connect
client.on_message = on_message
client.on_disconnect = on_disconnect

try:
    print(f"🔌 Connecting to {MQTT_BROKER}:{MQTT_PORT}...")
    client.connect(MQTT_BROKER, MQTT_PORT, 60)
    
    # Blocking call that processes network traffic and dispatches callbacks
    client.loop_forever()
    
except KeyboardInterrupt:
    print("\n\n👋 Stopping MQTT monitor...")
    client.disconnect()
    print("✅ Disconnected successfully")
    
except Exception as e:
    print(f"\n❌ Error: {e}")
