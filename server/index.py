import flask
from waitress import serve
import json
import io
import time
import torch
from PIL import Image
from torchvision.models import get_weight, get_model
from torchvision.io import read_image

import numpy as np

app = flask.Flask(__name__)
image = None
model = None
labels = None
log_enabled = True
base_dir = "/workspace"

def initialize():
    global model, labels, image

    # Load image
    # with Image.open(base_dir + '/car.jpg') as img:
    #     image = io.BytesIO()
    #     img.save(image, format='JPEG')
    #     image.seek(0)
    # image = transform_image(image)
    raw_image = read_image("./car.jpg")
    raw_image = raw_image.to("cuda:0" if torch.cuda.is_available() else "cpu")


    # Load model from torchvision
    # model = retinanet_resnet50_fpn_v2(weights=RetinaNet_ResNet50_FPN_V2_Weights.DEFAULT)
    model = get_model("fasterrcnn_resnet50_fpn_v2",weights="DEFAULT")
    model = model.to("cuda:0" if torch.cuda.is_available() else "cpu")
    model.eval()

    # Transform image
    weights = get_weight('FasterRCNN_ResNet50_FPN_V2_Weights.DEFAULT')
    transform = weights.transforms()
    image = transform(raw_image)
    image = image.unsqueeze(0)

    # with open(base_dir + '/retinanet_class_index.json') as json_file:
    #     labels = json.loads(json_file.read())

def post_process(result):
    bboxes_ = result[0] 
    scores_ = result[1] 
    labels_ = result[2]
    topk = min(5, len(bboxes_))
    labels_ = [labels[str(idx)] for idx in labels_[:topk]]
    result = [bboxes_[:topk].tolist(), labels_, scores_[:topk].tolist()]
    return result

@app.route("/predict", methods=["POST"])
def predict():
    data = {"success": False}

    if flask.request.method == "POST":
        with torch.no_grad():
            _ = model(image)
        data["success"] = True

    return flask.jsonify(data)

if __name__ == "__main__":
    print("Loading Torchvision model, and starting Flask server")       
    initialize()
    print("Loading complete")    
    serve(app, host="0.0.0.0", port=5000)
