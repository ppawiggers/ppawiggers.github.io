FROM jekyll/jekyll:4

WORKDIR /app

RUN gem install github-pages webrick

RUN jekyll serve
