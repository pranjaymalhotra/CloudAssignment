"""
Flink Streaming Job - E-Commerce Analytics
Consumes from Kafka, performs 1-minute windowed aggregation, publishes to results topic
"""

from pyflink.datastream import StreamExecutionEnvironment
from pyflink.table import StreamTableEnvironment, EnvironmentSettings
from pyflink.table.window import Tumble
import os

def create_flink_job():
    # Create execution environment
    env = StreamExecutionEnvironment.get_execution_environment()
    env.set_parallelism(2)
    
    # Create table environment
    settings = EnvironmentSettings.new_instance().in_streaming_mode().build()
    table_env = StreamTableEnvironment.create(env, environment_settings=settings)
    
    # Configuration from environment variables
    kafka_brokers = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092')
    input_topic = os.getenv('KAFKA_INPUT_TOPIC', 'orders-events')
    output_topic = os.getenv('KAFKA_OUTPUT_TOPIC', 'analytics-results')
    
    # Create Kafka source table for order events
    table_env.execute_sql(f"""
        CREATE TABLE order_events (
            user_id VARCHAR,
            product_id VARCHAR,
            order_id VARCHAR,
            quantity INT,
            price DECIMAL(10, 2),
            timestamp TIMESTAMP(3),
            WATERMARK FOR timestamp AS timestamp - INTERVAL '5' SECOND
        ) WITH (
            'connector' = 'kafka',
            'topic' = '{input_topic}',
            'properties.bootstrap.servers' = '{kafka_brokers}',
            'properties.group.id' = 'flink-analytics',
            'scan.startup.mode' = 'latest-offset',
            'format' = 'json',
            'json.fail-on-missing-field' = 'false',
            'json.ignore-parse-errors' = 'true'
        )
    """)
    
    # Create Kafka sink table for aggregated results
    table_env.execute_sql(f"""
        CREATE TABLE analytics_results (
            window_start TIMESTAMP(3),
            window_end TIMESTAMP(3),
            unique_users BIGINT,
            total_orders BIGINT,
            total_revenue DECIMAL(10, 2),
            avg_order_value DECIMAL(10, 2)
        ) WITH (
            'connector' = 'kafka',
            'topic' = '{output_topic}',
            'properties.bootstrap.servers' = '{kafka_brokers}',
            'format' = 'json'
        )
    """)
    
    # Perform 1-minute windowed aggregation
    # Count unique users, total orders, and total revenue per window
    table_env.execute_sql("""
        INSERT INTO analytics_results
        SELECT
            TUMBLE_START(timestamp, INTERVAL '1' MINUTE) as window_start,
            TUMBLE_END(timestamp, INTERVAL '1' MINUTE) as window_end,
            COUNT(DISTINCT user_id) as unique_users,
            COUNT(*) as total_orders,
            SUM(price * quantity) as total_revenue,
            AVG(price * quantity) as avg_order_value
        FROM order_events
        GROUP BY TUMBLE(timestamp, INTERVAL '1' MINUTE)
    """)

def main():
    """Main entry point for Flink job"""
    print("Starting Flink Analytics Job...")
    print(f"Kafka Brokers: {os.getenv('KAFKA_BOOTSTRAP_SERVERS')}")
    print(f"Input Topic: {os.getenv('KAFKA_INPUT_TOPIC', 'orders-events')}")
    print(f"Output Topic: {os.getenv('KAFKA_OUTPUT_TOPIC', 'analytics-results')}")
    
    try:
        create_flink_job()
        print("Flink job submitted successfully!")
    except Exception as e:
        print(f"Error running Flink job: {e}")
        raise

if __name__ == '__main__':
    main()
