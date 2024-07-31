# FaaS watchdog image
FROM --platform=${TARGETPLATFORM:-linux/amd64}  ghcr.io/openfaas/of-watchdog:0.9.6 as watchdog
# Base Image
FROM pytorch/pytorch:2.3.1-cuda11.8-cudnn8-devel

RUN apt-get update && apt-get install -y python3 python3-pip git && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
COPY requirements.txt .
RUN python3 -m pip install --disable-pip-version-check -U -r requirements.txt

# Jupyter (optional to run notebook inside the container)
# RUN pip install jupyter 
# EXPOSE 8888

## Prepare src code 
COPY . .

## Setup FaaS components
WORKDIR /workspace/server
COPY --from=watchdog /fwatchdog /usr/bin/fwatchdog
RUN chmod +x /usr/bin/fwatchdog
ENV mode="http"
ENV upstream_url="http://127.0.0.1:5000"
ENV read_timeout="60s"
ENV write_timeout="60s"
ENV exec_timeout="60s"
ENV fprocess="python3 index.py"

# Without Jupyter
CMD ["fwatchdog"]
# With Jupyter
# CMD jupyter notebook --ip=0.0.0.0 --port=8888 --no-browser --allow-root & fwatchdog
