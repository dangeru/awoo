FROM ruby:2.7-slim
LABEL maintainer="Illia P. <sudokamikaze@protonmail.com>"

ENV MYSQL_USER awoo
ENV MYSQL_PASSWORD awoo
ENV MYSQL_HOST "mysql"
ENV MYSQL_DATABASE awoo
ENV RUBYOPT="-w"
ENV APP_HOME="/app"

COPY src /app
COPY entrypoint.sh /app/entrypoint.sh

RUN apt update && apt install -y build-essential \
    imagemagick libmariadb-dev wamerican \
    && gem install bundler \
    && bundle install --gemfile=/app/Gemfile \
    && useradd -r -U awoo \
    && chown -R awoo:awoo /app \
    && apt purge --auto-remove -y build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
USER awoo

CMD [ "/app/entrypoint.sh" ]