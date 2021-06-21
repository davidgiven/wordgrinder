FROM debian:latest

RUN apt-get update && apt-get install -y build-essential ninja-build libncursesw5-dev liblua5.2-dev zlib1g-dev libxft-dev

COPY . /app

WORKDIR /app

RUN make

#binaries end up under bin/ directory!
RUN cp bin/wordgrinder-builtin-curses-release /bin/wordgrinder

CMD /bin/wordgrinder


