FROM flink:1.17-scala_2.12-java11

# Install Python and dependencies
RUN apt-get update && \
    apt-get install -y python3 python3-pip wget && \
    rm -rf /var/lib/apt/lists/*

# Download Flink Kafka connector JAR
RUN wget -P /opt/flink/lib/ https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-kafka/1.17.0/flink-sql-connector-kafka-1.17.0.jar

# Install PyFlink and Kafka
RUN pip3 install apache-flink==1.17.0 kafka-python

# Copy the Flink job
COPY analytics_job.py /opt/flink/job/analytics_job.py

# Set working directory
WORKDIR /opt/flink/job

# Run the job
CMD ["python3", "/opt/flink/job/analytics_job.py"]
