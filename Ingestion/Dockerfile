# Use a lightweight official Python runtime
FROM python:3.11-slim

# Prevent Python from writing .pyc files and buffer stdout/stderr
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Set the working directory inside the container
WORKDIR /app

# Copy dependency list and install requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the extraction script into the container
COPY extract_to_s3.py extract_complaints.py ./

# Define the command to execute when the container starts
CMD ["python", "extract_to_s3.py"]