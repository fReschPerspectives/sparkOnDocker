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

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

USER root

RUN set -ex; \
    apt-get update; \
    apt-get install -y python3 python3-pip; \
    apt-get install -y r-base r-base-dev; \
    apt-get install -y pandoc; \
    rm -rf /var/lib/apt/lists/*

ENV R_HOME=/usr/lib/R

# Install sparklyr and dependencies in R
RUN R -e "install.packages(c('sparklyr', 'tidyverse'), repos='http://cran.rstudio.com/')"

# Create a user for RStudio
RUN useradd -ms /bin/bash rstudio \
    && echo "rstudio:rstudio" | chpasswd \
    && adduser rstudio sudo

# Download and install RStudio Server
RUN wget https://download2.rstudio.org/server/jammy/amd64/rstudio-server-2023.06.2-561-amd64.deb && \
    gdebi --non-interactive rstudio-server-2023.06.2-561-amd64.deb && \
    rm rstudio-server-2023.06.2-561-amd64.deb

# Expose default RStudio Server port
EXPOSE 8787

# Start RStudio Server
CMD ["/usr/lib/rstudio-server/bin/rserver", "--server-daemonize=0"]

USER spark