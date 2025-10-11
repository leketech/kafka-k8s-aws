import argparse
import sys
import os
from confluent_kafka import Producer, Consumer, KafkaException

BOOTSTRAP_SERVER = os.getenv("KAFKA_BOOTSTRAP", "localhost:9094")
TOPIC = "test-topic"

def delivery_report(err, msg):
    if err:
        print(f"❌ Message failed delivery: {err}")
    else:
        print(f"✅ Sent: {msg.value().decode('utf-8')}")

def produce_message(message: str):
    conf = {
        'bootstrap.servers': BOOTSTRAP_SERVER,
        'security.protocol': 'PLAINTEXT',  # 👈 Explicitly set
        'socket.connection.setup.timeout.ms': 10000,
        'message.timeout.ms': 300000,  # 👈 Increased to 5 minutes (matches AWS NLB)
        'retries': 3
    }
    producer = Producer(conf)
    try:
        producer.produce(TOPIC, message.encode('utf-8'), callback=delivery_report)
        producer.flush(timeout=300)  # 👈 Match message.timeout.ms
    except KafkaException as e:
        print(f"Producer error: {e}")
        sys.exit(1)

def consume_messages():
    conf = {
        'bootstrap.servers': BOOTSTRAP_SERVER,
        'security.protocol': 'PLAINTEXT',  # 👈 Explicitly set
        'group.id': 'python-consumer-group',
        'auto.offset.reset': 'earliest',
        'socket.connection.setup.timeout.ms': 10000,
        'session.timeout.ms': 45000,  # 👈 Must be <= group.max.session.ms (default 60s)
        'heartbeat.interval.ms': 15000
    }
    consumer = Consumer(conf)
    consumer.subscribe([TOPIC])

    print("👂 Listening for messages... (Ctrl+C to stop)")
    try:
        while True:
            msg = consumer.poll(timeout=1.0)
            if msg is None:
                continue
            if msg.error():
                print(f"Consumer error: {msg.error()}")
            else:
                print(f"📨 Received: {msg.value().decode('utf-8')}")
    except KeyboardInterrupt:
        print("\n🛑 Stopping consumer...")
    finally:
        consumer.close()

def get_bootstrap_instructions():
    """Print instructions for finding the bootstrap server for both deployment approaches."""
    print("\n🔧 To find your Kafka bootstrap server, use one of the following commands:")
    print("\nFor Strimzi deployment:")
    print("  kubectl get svc my-kafka-kafka-external-bootstrap -n kafka -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'")
    print("  Then: export KAFKA_BOOTSTRAP=<hostname>:9094")
    
    print("\nFor StatefulSet deployment:")
    print("  kubectl get svc kafka-service -n kafka -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'")
    print("  Then: export KAFKA_BOOTSTRAP=<hostname>:9092")
    
    print("\nFor local development:")
    print("  export KAFKA_BOOTSTRAP=localhost:9094")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Kafka Producer/Consumer for AWS EKS")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--produce", metavar="MESSAGE", help="Message to send to Kafka")
    group.add_argument("--consume", action="store_true", help="Start consuming messages")
    parser.add_argument("--show-bootstrap", action="store_true", help="Show instructions for finding bootstrap server")

    args = parser.parse_args()

    # Check if we're using the default localhost value and warn the user
    if BOOTSTRAP_SERVER == "localhost:9094":
        print("⚠️  WARNING: Using default bootstrap server 'localhost:9094'")
        get_bootstrap_instructions()

    if args.show_bootstrap:
        get_bootstrap_instructions()
        sys.exit(0)

    if args.produce:
        produce_message(args.produce)
    elif args.consume:
        consume_messages()