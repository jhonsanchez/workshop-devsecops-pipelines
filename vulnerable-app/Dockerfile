# VULNERABLE Dockerfile — used as the "before" example in Lab 6
# VULNERABLE: Using old Python version AND 'latest' tag pattern is bad practice
FROM python:3.11

USER root

COPY . /app
WORKDIR /app

RUN pip install -r requirements.txt

RUN apt-get update && apt-get install -y curl vim wget netcat-openbsd

EXPOSE 22 8080

ENV FLASK_ENV=development
ENV DATABASE_PASSWORD=Entelgy2024!Prod

CMD ["python", "app.py"]
