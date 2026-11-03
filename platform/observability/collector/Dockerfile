FROM python:3.11-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY collector.py /app/collector.py
USER 10001:10001
ENTRYPOINT ["python", "/app/collector.py"]
