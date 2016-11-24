FROM ruby:2.3.1

ENV RAILS_ROOT /var/apps/release

RUN mkdir -p $RAILS_ROOT

WORKDIR $RAILS_ROOT

# Copy the Gemfile over first so that we only need to generate
# a new intermediate container whenever the bundle changes.
COPY Gemfile Gemfile
COPY Gemfile.lock Gemfile.lock
RUN bundle install

# The uglifier gem needs a JavaScript runtime
RUN apt-get update
RUN apt-get install -y nodejs

COPY . .

EXPOSE 3036

ENTRYPOINT ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
