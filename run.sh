#!/bin/bash
CSV_FILE="TEST_retinanet_resnet50_fpn_v2.csv"
DOCKER_START_WAITING_TIME=7
DOCKER_END_WAITING_TIME=5
QUOTAS=(3 4 5 6 7 8 9 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100)

echo '"gpu_quota","throughput","req_count","avg_latency","p90_latency","p95_latency"' > "$CSV_FILE"
for quota in "${QUOTAS[@]}"; do
    echo "====================QUOTA: $quota%======================================================="
    docker run -e CUDA_MPS_PIPE_DIRECTORY=/tmp/nvidia-mps  -e CUDA_MPS_LOG_DIRECTORY=/tmp/nvidia-log \
        -e CUDA_MPS_ACTIVE_THREAD_PERCENTAGE=$quota \
        --network host --rm --name retinafpn --ipc=host retinafpn &
    sleep $DOCKER_START_WAITING_TIME

    # Run k6
    output=$(k6 run client/k6.js)
    throughput=$(echo "$output" | tail -n 8 | head -n 1)
    req_count=$(echo "$output" | tail -n 7 | head -n 1)
    avg_latency=$(echo "$output" | tail -n 6 | head -n 1)
    p90_latency=$(echo "$output" | tail -n 5 | head -n 1)
    p95_latency=$(echo "$output" | tail -n 4 | head -n 1)

    # Print and save to csv
    echo -e "THROUGHPUT: $throughput\nREQ_COUNTt: $req_count\nAVG_LATENCY: $avg_latency\nP90_LATENCY: $p90_latency\nP95_LATENCY: $p95_latency"
    echo "$quota","$throughput","$req_count","$avg_latency","$p90_latency","$p95_latency" >> "$CSV_FILE"
    docker stop retinafpn
    sleep $DOCKER_END_WAITING_TIME
done