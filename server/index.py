import flask
from waitress import serve
import os
import sys
import json
import io
import torch
from PIL import Image
from torchvision.models import get_weight, get_model
from torchvision.io import read_image

import numpy as np

app = flask.Flask(__name__)
image = None
model = None
base_dir = "/workspace"

def initialize():
    global model, image

    # Parse model name from env
    model_name = os.getenv('MODEL')
    if model_name is None:
        print(f"Error: MODEL is not set.", file=sys.stderr)
        sys.exit(1)
    print(f"Model: {model_name}")

    with open('./models_and_weights.json') as json_file:
        models_and_weights = json.loads(json_file.read())
    if model_name not in models_and_weights:
        print(f"Error: Model {model_name} not found in models_and_weights.json", file=sys.stderr)
        sys.exit(1)

    model = models_and_weights[model_name]['model']
    weights = models_and_weights[model_name]['weights']

    # Load model from torchvision
    model = get_model(model, weights="DEFAULT")
    model = model.to("cuda:0" if torch.cuda.is_available() else "cpu")
    model.eval()

    # Load image as input to model
    raw_image = read_image("./car.jpg")
    raw_image = raw_image.to("cuda:0" if torch.cuda.is_available() else "cpu")

    # Transform image
    weights = get_weight(weights)
    transform = weights.transforms()
    image = transform(raw_image)
    image = image.unsqueeze(0)

@app.route("/predict", methods=["POST"])
def predict():
    data = {"success": False}

    if flask.request.method == "POST":
        with torch.no_grad():
            _ = model(image)
            torch.cuda.empty_cache()
        data["success"] = True

    return flask.jsonify(data)

if __name__ == "__main__":
    print("Loading Torchvision model, and starting Flask server")       
    initialize()
    print("Loading complete")    
    serve(app, host="0.0.0.0", port=5000)
