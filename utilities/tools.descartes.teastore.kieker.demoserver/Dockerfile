FROM openjdk:11-jdk-slim

# Environment Variables
ENV KIEKER_HOME=/opt/kieker
ENV PATH="$KIEKER_HOME/bin:$PATH"

RUN apt-get update && \
    apt-get install -y \
      graphviz \
      plotutils \
      bash \
      nodejs \
      npm \
      supervisor \
      unzip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

#      gnuplot \
#      ghostscript \
COPY supervisord.conf /etc/supervisord.conf

# Get the Contents from the Server to the Container
RUN mkdir -p $KIEKER_HOME
COPY server/ $KIEKER_HOME

# Extract Kieker Trace Analysis Binaries
COPY trace-analysis-1.15.zip /trace-analysis.zip
RUN unzip trace-analysis.zip 
RUN cp -r trace-analysis-1.15/* "$KIEKER_HOME/java/trace-analysis"

RUN chmod +x $KIEKER_HOME/java/compileAndRunJava.sh
RUN chmod +x $KIEKER_HOME/java/graph_scripts/agg_deployment_call_tree.sh
RUN chmod +x $KIEKER_HOME/java/graph_scripts/deployment_op_dep.sh


WORKDIR $KIEKER_HOME/nodejs_server
RUN npm install --production

# Expose the port 3000 for the NodeJS server and 3001 for the Socket connection with RabbitMQ
WORKDIR /
EXPOSE 3000 3001

# Run the Server
CMD [ "supervisord", "-c", "/etc/supervisord.conf" ]
