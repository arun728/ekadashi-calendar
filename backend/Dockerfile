FROM python:3.12-slim
WORKDIR /app
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY backend/ekadashi_billing /app/ekadashi_billing
COPY assets/calendar /app/assets/calendar
ENV CALENDAR_ASSET_PATH=/app/assets/calendar
RUN useradd --create-home appuser
USER appuser
EXPOSE 8080
CMD ["uvicorn", "ekadashi_billing.api:production_app", "--factory", "--host", "0.0.0.0", "--port", "8080", "--no-access-log"]
