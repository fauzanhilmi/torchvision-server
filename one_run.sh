#!/bin/bash
############################ Variables to change ###################################
MODELS=("lraspp_mobilenet_v3_large")
CUR_MODELS=("${MODELS[@]}")
DOCKER_START_WAITING_TIME=2
DOCKER_END_WAITING_TIME=2
# QUOTAS=(3 4 5 6 7 8 9 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100)
QUOTAS=(25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100)
####################################################################################

echo "Running for models: ${CUR_MODELS[@]}"

# In case there's dangling container
docker stop visionserver
while docker ps | grep -q visionserver; do
    sleep 1
done
sleep $DOCKER_END_WAITING_TIME

# Run each model under different GPU quotas
for MODEL in "${CUR_MODELS[@]}"; do
    CSV_FILE="$MODEL.temp.csv"

    echo '"gpu_quota","throughput","req_count","avg_latency","p90_latency","p95_latency"' > "$CSV_FILE"
    for QUOTA in "${QUOTAS[@]}"; do
        echo "========================================================================================="
        echo MODEL: $MODEL
        echo QUOTA: $QUOTA%
        echo "========================================================================================="
        docker run -e CUDA_MPS_PIPE_DIRECTORY=/tmp/nvidia-mps  -e CUDA_MPS_LOG_DIRECTORY=/tmp/nvidia-log \
            -e CUDA_MPS_ACTIVE_THREAD_PERCENTAGE=$QUOTA \
            -e MODEL=$MODEL \
            --network host --rm --name visionserver --ipc=host visionserver &
        while ! docker logs --tail 1 visionserver 2>&1 | grep -q 100; do
            sleep 1
        done
        sleep $DOCKER_START_WAITING_TIME

        # Run k6
        output=$(k6 run client/k6.js)
        throughput=$(echo "$output" | tail -n 8 | head -n 1)
        req_count=$(echo "$output" | tail -n 7 | head -n 1)
        avg_latency=$(echo "$output" | tail -n 6 | head -n 1)
        p90_latency=$(echo "$output" | tail -n 5 | head -n 1)
        p95_latency=$(echo "$output" | tail -n 4 | head -n 1)

        # Print and save to csv
        echo -e "THROUGHPUT: $throughput\nREQ_COUNT: $req_count\nAVG_LATENCY: $avg_latency\nP90_LATENCY: $p90_latency\nP95_LATENCY: $p95_latency"
        echo "$QUOTA","$throughput","$req_count","$avg_latency","$p90_latency","$p95_latency" >> "$CSV_FILE"
        docker stop visionserver
        while docker ps | grep -q visionserver; do
            sleep 1
        done
        sleep $DOCKER_END_WAITING_TIME
    done
done