FROM ruby:3.0.1-buster

WORKDIR /app

COPY Gemfile* .ruby-version ./
COPY vendor/cache vendor/cache
COPY script script/
RUN gem install "bundler:>2" && script/bootstrap

COPY . .

CMD ["script/generate", "-d", "cards/", "-l", "-o", "output"]
