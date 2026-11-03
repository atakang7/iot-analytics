FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app
COPY stream-worker/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY common ./common
COPY stream-worker/main.py ./main.py
RUN useradd --system --uid 10001 app
USER 10001
EXPOSE 8000

CMD ["python", "main.py"]
