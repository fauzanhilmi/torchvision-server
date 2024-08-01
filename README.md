# torchvision-server
Containerized Flask server for serving Torchvision model inference

Torch version 2.3.1 (see Dockerfile base image)
Torchvision version 0.19

Note: not all models are implemented. See `server/implemented_models.txt`

## How to run
`docker build -t visionserver .`

`docker run MODEL=alexnet --network host --rm --name visionserver --ipc=host visionserver`

replace MODEL with other model
