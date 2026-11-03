FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app
COPY kpi-job/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY common ./common
COPY kpi-job/main.py ./main.py
RUN useradd --system --uid 10001 app
USER 10001

CMD ["python", "main.py"]
