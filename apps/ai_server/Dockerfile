FROM python:3.12-slim

WORKDIR /usr/src/app

# Install system dependencies required by OpenCV
RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# Copy python dependency list
COPY requirements.txt ./

# Install python libraries
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY . .

# Create directory for ONNX models
RUN mkdir -p models

ENV PORT=3002
EXPOSE 3002

CMD ["python", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "3002"]
