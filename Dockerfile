#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
FROM spark:3.5.6-scala2.12-java11-ubuntu

USER root

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Accept architecture as a build argument
ARG TARGETARCH="arm64"
ENV arch=${TARGETARCH}

ARG JAVA_VERSION="17"
ENV JAVA_VERSION=${JAVA_VERSION}

# Get needed dependencies
RUN set -ex; \
    apt-get update && \
    apt-get install -y \
        python3 \
        python3-pip \
        build-essential \
        software-properties-common \
        r-base \
        r-base-core \
        r-base-dev \
        r-recommended \
        cmake \
        make \
        ant \
        openjdk-11-jdk \
        openjdk-17-jdk \
        lsb-release \
        libpam0g-dev \
        libssl-dev \
        libcurl4-openssl-dev \
        libjpeg-dev \
        libpng-dev \
        libsqlite3-dev \
        libpq-dev \
        libbz2-dev \
        libzstd-dev \
        libxml2-dev \
        qtbase5-dev \
        qttools5-dev \
        qttools5-dev-tools \
        libqt5websockets5-dev \
        libgl1-mesa-dev \
        protobuf-compiler \
        libprotobuf-dev \
        zlib1g-dev \
        libedit-dev \
        uuid-dev \
        devscripts \
        fakeroot \
        git \
        pandoc && \
    rm -rf /var/lib/apt/lists/*

# Apparently need a newer cmake
RUN wget "https://github.com/Kitware/CMake/releases/download/v3.28.3/cmake-3.28.3-linux-$(uname -m).sh" && \
    chmod +x "cmake-3.28.3-linux-$(uname -m).sh"

# Install to /opt/cmake
RUN mkdir /opt/cmake && \
    ./cmake-3.28.3-linux-$(uname -m).sh --skip-license --prefix=/opt/cmake

# Add to PATH
ENV PATH=/opt/cmake/bin:$PATH

# Verify CMake installation
RUN /opt/cmake/bin/cmake --version

# Set JAVA_HOME for RStudio 
ENV JAVA_HOME="/usr/lib/jvm/java-${JAVA_VERSION}-openjdk-$arch" 
ENV PATH="$JAVA_HOME/bin:$PATH"
RUN echo "export JAVA_HOME=$JAVA_HOME" >> ~/.bashrc

# Verify JAVA_HOME
RUN echo $JAVA_HOME
RUN java -version

# Set PATH for R and Python
RUN echo $PATH
RUN echo 'export PATH=$PATH' >> ~/.bashrc

# Install modern Node.js (18.x)
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs

# Verify NODE installation
RUN node --version


ENV R_HOME=/usr/lib/R

# Install Python dependencies
RUN pip3 install --no-cache-dir \
    pyspark==3.5.6 \
    findspark \
    pandas \
    numpy \
    matplotlib \
    seaborn \
    scikit-learn \
    jupyterlab \
    ipykernel \
    && python3 -m ipykernel install --user --name=spark-py3

# Install sparklyr and dependencies in R
RUN R -e "install.packages(c('remotes'))" && \
    R -e 'remotes::install_version("cpp11", version = "0.5.0", repos = "https://cran.r-project.org")' && \
    R -e 'remotes::install_version("purrr", version = "1.0.2", repos = "https://cran.r-project.org")' && \
    R -e 'remotes::install_version("tzdb", version = "0.4.0", repos = "https://cran.r-project.org")' && \
    R -e 'remotes::install_version("gtable", version = "0.3.5", repos = "https://cran.r-project.org")' && \
    R -e 'remotes::install_version("scales", version = "1.3.0", repos = "https://cran.r-project.org")' && \
    R -e 'remotes::install_version("tidyr", version = "1.3.0", repos = "https://cran.r-project.org")' && \
    R -e 'remotes::install_version("readr", version = "2.1.5", repos = "https://cran.r-project.org")' && \
    R -e 'remotes::install_version("tidyverse", version = "1.3.1", repos = "https://cran.r-project.org")' && \
    R -e 'remotes::install_version("sparklyr", version = "1.8.0", repos = "https://cran.r-project.org")'

# Create a user for RStudio
RUN useradd -ms /bin/bash rstudio \
    && echo "rstudio:rstudio" | chpasswd \
    && adduser rstudio sudo

# Download and install RStudio Server
RUN git clone https://github.com/rstudio/rstudio.git && \
    cd rstudio && \
    git submodule update --init --recursive 
    
# Verify the dependencies location and run the build
RUN cd rstudio/dependencies/linux && \
    cp install-dependencies-focal install-dependencies_focal_alt && \
    sed -i 's/sudo //g' install-dependencies_focal_alt 

RUN cd rstudio/dependencies/linux && \
    ./install-dependencies_focal_alt


RUN apt-get install -y openjdk-11-jdk-headless    
RUN readlink -f $(which javac)
ENV JAVA_HOME="/opt/java/openjdk-11-openjdk-$arch" 
RUN export JAVA_HOME="JAVA_HOME"

# Build RStudio Server
# Note: This step can take a while depending on the system
RUN cd rstudio && \
    mkdir build && cd build && \
    /opt/cmake/bin/cmake -DRSTUDIO_TARGET=Server \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/lib/rstudio-server \
        .. && \
    make && \
    make install

# Start RStudio Server
# Create startup script
COPY startup.sh /startup.sh
RUN chmod +x /startup.sh

# Expose default RStudio Server port and JupyterLab port
EXPOSE 8787
EXPOSE 8888

CMD ["/startup.sh"]