from flask import Flask, render_template, send_from_directory
import platform
import os
import sys
import json
import traceback
import base64
from io import BytesIO

app = Flask(__name__, static_folder='static')

# Get the system architecture
ARCH = platform.machine().lower()
# Map architecture names to standardized formats
ARCH_MAP = {
    'x86_64': 'amd64',
    'amd64': 'amd64',
    'arm64': 'arm64',
    'aarch64': 'arm64',
}
STD_ARCH = ARCH_MAP.get(ARCH, ARCH)

# Default port
DEFAULT_PORT = 5000

def process_image_with_opencv():
    """
    Try to import and use OpenCV to process an image,
    which will fail if the architecture of the OpenCV binary doesn't match the host architecture
    """
    try:
        import cv2
        import numpy as np
        
        # Get OpenCV version and build info
        version = cv2.__version__
        
        # Load the image
        image_path = os.path.join(app.static_folder, 'audience.png')
        original_img = cv2.imread(image_path)
        
        if original_img is None:
            raise Exception(f"Failed to load image from {image_path}")
        
        # Apply a much stronger Gaussian blur
        blurred_img = cv2.GaussianBlur(original_img, (101, 101), 0)
        
        # Convert to grayscale
        grayscale_img = cv2.cvtColor(original_img, cv2.COLOR_BGR2GRAY)
        # Convert grayscale back to BGR for consistent encoding
        grayscale_img = cv2.cvtColor(grayscale_img, cv2.COLOR_GRAY2BGR)
        
        # Convert images to base64 for embedding in HTML
        _, original_buffer = cv2.imencode('.png', original_img)
        _, blurred_buffer = cv2.imencode('.png', blurred_img)
        _, grayscale_buffer = cv2.imencode('.png', grayscale_img)
        
        original_b64 = base64.b64encode(original_buffer).decode('utf-8')
        blurred_b64 = base64.b64encode(blurred_buffer).decode('utf-8')
        grayscale_b64 = base64.b64encode(grayscale_buffer).decode('utf-8')
        
        # Get more detailed build information
        build_info = cv2.getBuildInformation()
        
        return {
            "status": "success",
            "message": f"Successfully loaded OpenCV {version} on {STD_ARCH}!",
            "details": {
                "version": version,
                "platform": platform.platform(),
                "python_version": platform.python_version(),
                "arch": STD_ARCH,
                "build_info_excerpt": build_info[:500] + "..." # Truncate for display
            },
            "images": {
                "original": original_b64,
                "blurred": blurred_b64,
                "grayscale": grayscale_b64
            }
        }
    except ImportError as e:
        return {
            "status": "error",
            "message": f"Failed to import OpenCV on {STD_ARCH}",
            "details": str(e),
            "images": None
        }
    except Exception as e:
        return {
            "status": "error",
            "message": f"Error using OpenCV on {STD_ARCH}",
            "details": f"{str(e)}\n{traceback.format_exc()}",
            "images": None
        }

@app.route('/')
def index():
    opencv_result = process_image_with_opencv()
    return render_template(
        'index.html',
        status=opencv_result["status"],
        message=opencv_result["message"],
        details=opencv_result["details"],
        images=opencv_result["images"],
        arch=STD_ARCH,
        platform=platform.platform()
    )

@app.route('/static/<path:filename>')
def serve_static(filename):
    return send_from_directory(app.static_folder, filename)

if __name__ == '__main__':
    port = DEFAULT_PORT

    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            print(f"Invalid port number: {sys.argv[1]}")

    app.run(host='0.0.0.0', port=port, debug=True)
    
