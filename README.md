# Water Meter Reader

## Introduction
This project is designed for the automatic reading of water meter digits using deep learning techniques. The YOLOv8 model, developed by Ultralytics, is employed for detecting the digits on the meter. The primary goal of this project is to simplify the water meter reading process and reduce errors.

## Features
- **YOLOv8 for Digit Detection**: The model detects and recognizes digits on water meter displays.
- **Image Preprocessing**: Includes essential steps such as resizing, scaling, and image quality enhancement to improve model performance.
- **Custom Dataset**: The model is trained using a labeled dataset of water meter images.
- **High Accuracy**: Accurate digit recognition from water meter images, whether in indoor or outdoor environments.

## Model
- The project uses **YOLOv8** for digit detection.
- The model is trained on custom datasets and fine-tuned to improve accuracy.

## Contribution
Your contributions are welcome! Feel free to report any issues or submit pull requests to enhance the project.

# How to use
```
python3 -m venv .venv
source .venv/bin/activate

python -m pip install --upgrade pip
pip install -r requirements.txt

python main.py
``` 
