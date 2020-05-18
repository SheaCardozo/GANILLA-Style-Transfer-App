# GANILLA-Style-Transfer-App

<img src="https://i.imgur.com/zSbTOoU.png " data-canonical-src="https://i.imgur.com/zSbTOoU.png " width="400" /><img src="https://i.imgur.com/FEMI5f3.png " data-canonical-src="https://i.imgur.com/FEMI5f3.png " width="400" />

This is a project that attempts to create a Android application that:
1. Captures images from the phone camera 
2. Passes the image to a GANILLA (a variant of CycleGAN) style-transfer model
3. Displays the resulting generated image to the screen

The current model used is a pretrained model created from the authors of the original GANILLA paper trained using a "domain A" of mostly natural landscape photography and a "domain B" of images by illustrator Axel Scheffler. This model was picked because it generated the most stylistically interesting results, however theoretically any (256x256) trained generator of this structure could be inserted into the API script. It's also worth noting that since the chosen model was mostly trained using landscape photos passing images of anything else into the model results in fairly poor results.

Because GANILLA models cannot be (easily) deployed directly on device, this project is a bit tricky to run:
1. "app.py" needs to be run in the api folder with the path of the model as an argument, this starts up the Flask API that the Android application will communicate with.
2. The API_URL in the "main.dart" file needs to be adjusted to the IPv4 address of the machine the Flask API is running on. The application can then be compiled and transfered (or just run via your IDE) on a connected device.
3. Once the application is running on the device, as long as the device is connected to the same local network as the machine running the Flask API you should be able to take photos, process them through the style-transfer model, and then save them locally through the app.

The app won't be able to process images if the port Flask API is listening on is not accepting inbound connections on the machine, usually because of a firewall. Either disable the fireall, or add a inbound rule to prevent this.

A possible future project would be to train a model using faces or something more suitable for use with a phone camera. As well as perhaps using higher-resolution images (although this would likely complicate training).
