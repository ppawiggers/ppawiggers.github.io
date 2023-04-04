FROM jekyll/jekyll:4

WORKDIR /app

RUN mkdir .jekyll-cache _site

RUN gem install github-pages webrick

COPY . .

CMD jekyll serve
