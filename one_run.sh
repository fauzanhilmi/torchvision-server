#!/bin/bash
# CLASSIFICATION_MODELS=("alexnet" "convnext_base" "convnext_large" "convnext_small" "convnext_tiny" "densenet121" "densenet161" "densenet169" "densenet201" "googlenet" "inception_v3" "mobilenet_v2" "mobilenet_v3_large" "mobilenet_v3_small" "resnet101" "resnet152" "resnet18" "resnet34" "resnet50" "vgg11_bn" "vgg11" "vgg13_bn" "vgg13" "vgg16_bn" "vgg16" "vgg19_bn" "vgg19" "vit_b_16" "vit_b_32" "vit_h_14" "vit_l_16" "vit_l_32")

# Read the JSON file
json=$(cat models_one_run.json)

# Use jq to parse the JSON and create a dict in the shell script
declare -A dict

# Loop over each key in the JSON object
for key in $(echo $json | jq -r 'keys[]'); do
    # Extract the values corresponding to the current key
    values=$(echo $json | jq -r --arg k "$key" '.[$k][]')
    # Convert the newline-separated values into a space-separated string
    values_array=()
    for value in $values; do
        values_array+=($value)
    done
    # Store the array as a string in the associative array
    dict[$key]="${values_array[@]}"
done
############################ Variables to change ###################################
MODELS=("vgg13_bn")
CUR_MODELS=("${MODELS[@]}")

DOCKER_START_WAITING_TIME=2
DOCKER_END_WAITING_TIME=2
# QUOTAS=(3 4 5 6 7 8 9 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100)
QUOTAS=(75)
####################################################################################

# echo "Running for models: ${CUR_MODELS[@]}"

# In case there's dangling container
docker stop visionserver
while docker ps | grep -q visionserver; do
    sleep 1
done
sleep $DOCKER_END_WAITING_TIME

# Run each model under different GPU quotas
for MODEL in "${CUR_MODELS[@]}"; do
# for MODEL in "${!dict[@]}"; do
    CSV_FILE="$MODEL.temp.csv"
    echo '"gpu_quota","throughput","req_count","avg_latency","p90_latency","p95_latency"' > "$CSV_FILE"

    for QUOTA in "${QUOTAS[@]}"; do
    # QUOTA_ARR=(${dict[$MODEL]})
    # for QUOTA in "${QUOTA_ARR[@]}"; do
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