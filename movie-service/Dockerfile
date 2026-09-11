FROM python:3.8-slim@sha256:1d52838af602b4b5a831beb13a0e4d073280665ea7be7f69ce2382f29c5a613f

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt requirements.lock /app/

# SQLAlchemy's optional C extensions are unnecessary for this exam workload.
RUN DISABLE_SQLALCHEMY_CEXT=1 pip install --no-cache-dir --no-build-isolation \
    -r requirements.txt -r requirements.lock \
    && pip check

COPY app/ /app/app/

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
