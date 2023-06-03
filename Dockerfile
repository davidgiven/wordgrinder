FROM debian:stable AS builder

RUN apt-get update && apt-get install -y build-essential ninja-build libncursesw5-dev liblua5.2-dev zlib1g-dev libxft-dev

COPY . /app

WORKDIR /app

RUN make

FROM debian:stable-slim

COPY --from=builder /app/bin/wordgrinder-builtin-curses-release /bin/wordgrinder

CMD /bin/wordgrinder


