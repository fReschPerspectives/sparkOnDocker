#!/bin/bash

# Start RStudio Server
/usr/lib/rstudio-server/bin/rserver --server-daemonize=0 &

# Start JupyterLab
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root &

# Keep container alive
wait
