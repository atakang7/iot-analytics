FROM python:3.11-slim

WORKDIR /app

COPY kpi-job/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY common ./common
COPY kpi-job/main.py .

CMD ["python", "main.py"]
