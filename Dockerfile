FROM dart:stable AS build
WORKDIR /app

COPY pubspec.* ./
RUN dart pub get
COPY . .

RUN dart compile exe bin/server.dart -o bin/server

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/server

EXPOSE 3000
ENV PORT=3000
ENV HOST=0.0.0.0

CMD ["/app/bin/server"]