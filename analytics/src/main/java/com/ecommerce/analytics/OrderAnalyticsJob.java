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
import org.apache.flink.streaming.api.CheckpointingMode;
import org.apache.flink.api.common.functions.MapFunction;
import org.apache.flink.api.java.tuple.Tuple2;
import org.apache.flink.metrics.Counter;
import org.apache.flink.configuration.Configuration;
import org.apache.flink.streaming.api.functions.windowing.ProcessWindowFunction;
import org.apache.flink.streaming.api.windowing.windows.TimeWindow;
import org.apache.flink.util.Collector;
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
        
        // Enable checkpointing for fault tolerance
        env.enableCheckpointing(60000); // Checkpoint every 60 seconds
        env.getCheckpointConfig().setCheckpointingMode(CheckpointingMode.EXACTLY_ONCE);
        env.getCheckpointConfig().setMinPauseBetweenCheckpoints(30000);
        env.getCheckpointConfig().setCheckpointTimeout(120000);
        env.getCheckpointConfig().setMaxConcurrentCheckpoints(1);
        
        // Set parallelism
        env.setParallelism(2);
        
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
            .map(new OrderParser())
            .keyBy(value -> value.f0)
            .window(TumblingProcessingTimeWindows.of(Time.minutes(1)))
            .process(new OrderAggregator());
        
        // Sink results back to Kafka
        analytics.sinkTo(sink);
        
        // Execute the Flink job
        env.execute("E-Commerce Order Analytics");
    }
    
    /**
     * Parse incoming order JSON and extract user_id
     */
    public static class OrderParser implements MapFunction<String, Tuple2<String, Integer>> {
        private transient Counter processedOrders;
        
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
    }
    
    /**
     * Aggregate orders by user in 1-minute windows with metrics
     */
    public static class OrderAggregator extends ProcessWindowFunction<Tuple2<String, Integer>, String, String, TimeWindow> {
        private transient Counter windowsProcessed;
        
        @Override
        public void open(Configuration parameters) throws Exception {
            super.open(parameters);
            this.windowsProcessed = getRuntimeContext()
                .getMetricGroup()
                .counter("windows_processed");
        }
        
        @Override
        public void process(String key, Context context, Iterable<Tuple2<String, Integer>> elements, Collector<String> out) throws Exception {
            int count = 0;
            for (Tuple2<String, Integer> element : elements) {
                count += element.f1;
            }
            
            // Increment metric
            windowsProcessed.inc();
            
            // Create result JSON
            JsonObject result = new JsonObject();
            result.addProperty("user_id", key);
            result.addProperty("order_count", count);
            result.addProperty("window_start", context.window().getStart());
            result.addProperty("window_end", context.window().getEnd());
            result.addProperty("processing_time", System.currentTimeMillis());
            
            out.collect(result.toString());
        }
    }
}
