import sys

from flask import request, url_for, send_file
from flask_api import FlaskAPI, status, exceptions
from utils.ganilla import init, forward
from PIL import Image
from datetime import datetime

app = FlaskAPI(__name__)
app.debug = False


@app.route("/", methods=['GET', 'POST'])
def run_model():
    if request.method == 'GET':
        return "test"

    now = datetime.now().strftime("%Y%m%d-%H%M%S")

    real = Image.open(request.files["image"]).resize((256, 256)).convert('RGB')
    im = forward(real, MODEL)
    fake = Image.fromarray(im)

    fake.save(f"outputs/{now}.jpg")
    return send_file(f"outputs/{now}.jpg", as_attachment=True)


if __name__ == "__main__":

    global MODEL

    assert len(sys.argv) == 2

    MODEL = init(sys.argv[1])

    app.run(host="0.0.0.0", port=5123, debug=False)

