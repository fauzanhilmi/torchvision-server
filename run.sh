#!/bin/bash
CLASSIFICATION_MODELS=("alexnet" "convnext_base" "convnext_large" "convnext_small" "convnext_tiny" "densenet121" "densenet161" "densenet169" "densenet201" "googlenet" "inception_v3" "mobilenet_v2" "mobilenet_v3_large" "mobilenet_v3_small" "resnet101" "resnet152" "resnet18" "resnet34" "resnet50" "vgg11_bn" "vgg11" "vgg13_bn" "vgg13" "vgg16_bn" "vgg16" "vgg19_bn" "vgg19" "vit_b_16" "vit_b_32" "vit_h_14" "vit_l_16" "vit_l_32")
OBJECT_DETECTION_MODELS=("fcos_resnet50_fpn" "fasterrcnn_mobilenet_v3_large_320_fpn" "fasterrcnn_mobilenet_v3_large_fpn" "fasterrcnn_resnet50_fpn_v2" "fasterrcnn_resnet50_fpn" "retinanet_resnet50_fpn_v2" "retinanet_resnet50_fpn" "ssd300_vgg16" "ssdlite320_mobilenet_v3_large")
SEMANTIC_SEGMENTATION_MODELS=("deeplabv3_mobilenet_v3_large" "deeplabv3_resnet101" "deeplabv3_resnet50" "fcn_resnet101" "fcn_resnet50" "lraspp_mobilenet_v3_large")
ALL_MODELS=("${CLASSIFICATION_MODELS[@]}" "${OBJECT_DETECTION_MODELS[@]}" "${SEMANTIC_SEGMENTATION_MODELS[@]}")

CUR_MODELS=$CLASSIFICATION_MODELS # Change this to run for different models

for MODEL in "${CUR_MODELS[@]}"; do
    CSV_FILE="$MODEL.csv"
    DOCKER_START_WAITING_TIME=2
    DOCKER_END_WAITING_TIME=2
    QUOTAS=(3 4 5 6 7 8 9 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100)

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