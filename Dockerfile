FROM ruby:3.1.0-alpine as webpacker

ENV RAILS_ENV=production
ENV NODE_ENV=production

WORKDIR /opt

RUN apk add --no-cache nodejs yarn git build-base python3 && \
    gem install shakapacker

COPY ./package.json ./yarn.lock ./

RUN yarn install

COPY ./bin/webpacker ./bin/webpacker
COPY ./config/webpack ./config/webpack
COPY ./config/webpacker.yml ./config/webpacker.yml
COPY ./postcss.config.js ./babel.config.js ./
COPY ./app/packs ./app/packs

RUN echo "gem 'shakapacker'" > Gemfile && ./bin/webpacker

FROM ruby:3.1.0-alpine as assets

WORKDIR /opt

RUN apk add --no-cache nodejs yarn git build-base python3

COPY ./vendor/motor-admin/ui/package.json ./vendor/motor-admin/ui/yarn.lock ./

RUN yarn install

COPY ./vendor/motor-admin/ui ./

RUN yarn build:prod

FROM ruby:3.1.0-alpine as app

ENV RAILS_ENV=production
ENV BUNDLE_WITHOUT="development:test"

WORKDIR /opt/motor-admin

RUN apk add --no-cache freetds-dev sqlite-dev libpq-dev mariadb-dev build-base

COPY ./Gemfile ./Gemfile.lock ./
COPY ./vendor/motor-admin/lib/motor/version.rb ./vendor/motor-admin/lib/motor/version.rb
COPY ./vendor/motor-admin/motor-admin.gemspec ./vendor/motor-admin/motor-admin.gemspec

RUN bundle update --bundler && bundle install && rm -rf ~/.bundle

COPY . ./

COPY --from=assets /opt/dist ./vendor/motor-admin/ui/dist
COPY --from=webpacker /opt/public/packs ./public/packs

RUN SECRET_KEY_BASE=bootsnap rails r "puts"
RUN ln -s /opt/motor-admin/bin/motor-admin /usr/local/bin && chmod +x /usr/local/bin/motor-admin

WORKDIR /app
ENV WORKDIR=/app/

EXPOSE 3000

CMD motor-admin
