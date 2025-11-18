package com.ecommerce.analytics;

import org.apache.flink.api.common.eventtime.WatermarkStrategy;
import org.apache.flink.api.common.serialization.SimpleStringSchema;
import org.apache.flink.connector.kafka.source.KafkaSource;
import org.apache.flink.connector.kafka.source.enumerator.initializer.OffsetsInitializer;
import org.apache.flink.connector.kafka.sink.KafkaRecordSerializationSchema;
import org.apache.flink.connector.kafka.sink.KafkaSink;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.windowing.assigners.TumblingProcessingTimeWindows;
import org.apache.flink.streaming.api.windowing.time.Time;
import org.apache.flink.api.common.functions.MapFunction;
import org.apache.flink.api.java.tuple.Tuple2;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

/**
 * Flink Analytics Job for E-Commerce Orders
 * Consumes from 'orders' Kafka topic
 * Performs 1-minute windowed aggregation
 * Publishes results to 'analytics-results' topic
 */
public class OrderAnalyticsJob {
    
    public static void main(String[] args) throws Exception {
        // Get Kafka brokers from environment or use default
        String kafkaBrokers = System.getenv().getOrDefault(
            "KAFKA_BOOTSTRAP_SERVERS", 
            "localhost:9092"
        );
        
        // Set up the streaming execution environment
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        
        // Configure Kafka source
        KafkaSource<String> source = KafkaSource.<String>builder()
            .setBootstrapServers(kafkaBrokers)
            .setTopics("orders")
            .setGroupId("flink-analytics-group")
            .setStartingOffsets(OffsetsInitializer.latest())
            .setValueOnlyDeserializer(new SimpleStringSchema())
            .build();
        
        // Configure Kafka sink for results
        KafkaSink<String> sink = KafkaSink.<String>builder()
            .setBootstrapServers(kafkaBrokers)
            .setRecordSerializer(KafkaRecordSerializationSchema.builder()
                .setTopic("analytics-results")
                .setValueSerializationSchema(new SimpleStringSchema())
                .build()
            )
            .build();
        
        // Create data stream from Kafka
        DataStream<String> orders = env.fromSource(
            source,
            WatermarkStrategy.noWatermarks(),
            "Kafka Orders Source"
        );
        
        // Process stream: parse JSON, extract user_id, aggregate by 1-minute window
        DataStream<String> analytics = orders
            .map(new MapFunction<String, Tuple2<String, Integer>>() {
                @Override
                public Tuple2<String, Integer> map(String value) throws Exception {
                    try {
                        JsonObject json = JsonParser.parseString(value).getAsJsonObject();
                        String userId = json.get("user_id").getAsString();
                        return new Tuple2<>(userId, 1);
                    } catch (Exception e) {
                        return new Tuple2<>("unknown", 1);
                    }
                }
            })
            .keyBy(value -> value.f0)
            .window(TumblingProcessingTimeWindows.of(Time.minutes(1)))
            .sum(1)
            .map(new MapFunction<Tuple2<String, Integer>, String>() {
                @Override
                public String map(Tuple2<String, Integer> value) throws Exception {
                    JsonObject result = new JsonObject();
                    result.addProperty("user_id", value.f0);
                    result.addProperty("order_count", value.f1);
                    result.addProperty("window_end", System.currentTimeMillis());
                    return result.toString();
                }
            });
        
        // Sink results back to Kafka
        analytics.sinkTo(sink);
        
        // Execute the Flink job
        env.execute("E-Commerce Order Analytics");
    }
}
