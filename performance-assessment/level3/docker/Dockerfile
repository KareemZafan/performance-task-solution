# One image for both roles: master (jmeter -n ... -R) and slave (jmeter-server).
FROM eclipse-temurin:17-jre
ARG JMETER_VERSION=5.6.3
RUN apt-get update && apt-get install -y --no-install-recommends curl procps iproute2 python3 \
 && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-${JMETER_VERSION}.tgz | tar -xz -C /opt \
 && ln -s /opt/apache-jmeter-${JMETER_VERSION} /opt/jmeter
ENV JMETER_HOME=/opt/jmeter PATH=/opt/jmeter/bin:$PATH
RUN curl -fsSL -o /opt/jmeter/lib/ext/jmeter-plugins-manager-1.10.jar https://repo1.maven.org/maven2/kg/apc/jmeter-plugins-manager/1.10/jmeter-plugins-manager-1.10.jar \
 && curl -fsSL -o /opt/jmeter/lib/cmdrunner-2.3.jar https://repo1.maven.org/maven2/kg/apc/cmdrunner/2.3/cmdrunner-2.3.jar \
 && java -cp /opt/jmeter/lib/ext/jmeter-plugins-manager-1.10.jar org.jmeterplugins.repository.PluginManagerCMDInstaller \
 && /opt/jmeter/bin/PluginsManagerCMD.sh install jpgc-casutg,jpgc-dummy
# 4 GB max heap on every node (task requirement)
COPY setenv.sh /opt/jmeter/bin/setenv.sh
WORKDIR /work
