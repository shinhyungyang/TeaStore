FROM openjdk:11-jdk-slim

ENV JMETER_VERSION 5.5

RUN apt-get update && \
    apt-get install -y \
      graphviz \
      wget \
      bash \
      unzip \
      iputils-ping \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*


# Environment Variables
ENV KIEKER_HOME=/opt/kieker
ENV PATH="$KIEKER_HOME/bin:$PATH"

# Get the Contents from the Server to the Container
RUN mkdir -p $KIEKER_HOME
COPY server/ $KIEKER_HOME

# Extract Kieker OpenTelemetry Transformer Binaries
COPY otel-transformer-2.0.0-SNAPSHOT.zip /otel-transformer.zip
RUN unzip otel-transformer.zip -d $KIEKER_HOME/


WORKDIR /
EXPOSE 10001

# Run the Server
CMD [ "/opt/kieker/otel-transformer-2.0.0-SNAPSHOT/bin/otel-transformer", "-lp", "10001", "--configuration", "opt/kieker/resources/kieker.monitoring.properties" ]
