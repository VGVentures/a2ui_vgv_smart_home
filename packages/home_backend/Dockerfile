# Production image for the Dart Frog server, for Google Cloud Run or any
# container host.
#
# Build it from the `dart_frog build` output, not the package root. `dart_frog
# build` vendors the `path:` dependency on the catalog package and copies the
# `assets/` directory into `build/`, so `build/` is a self-contained context:
#
#   dart pub get
#   dart_frog build
#   docker build -f Dockerfile build/ -t home-api
#
# This Dockerfile is the one dart_frog generates into `build/Dockerfile`, with
# one change: the runtime stage copies `assets/` and sets the working directory
# to the package root. The server reads its dotprompt assets by paths relative
# to the working directory (`assets/a2ui-prompt.prompt` is required and crashes
# boot if absent). Cloud Run sets PORT; Dart Frog reads it.

# Pinned to the workspace SDK rather than dart:stable so the image is
# reproducible across SDK releases.
FROM dart:3.12.1 AS build

WORKDIR /app

# Copy the vendored path dependencies before resolving.
COPY ./.dart_frog_path_dependencies  ./.dart_frog_path_dependencies

# Resolve app dependencies. The override pins the catalog to the vendored copy;
# the glob tolerates its absence for a build with no path dependencies.
COPY pubspec.* ./
COPY pubspec_overrides.yaml* ./
RUN dart pub get

# Copy app source code and AOT compile it.
COPY . .
# Ensure packages are still up-to-date if anything has changed.
RUN dart pub get --offline
# Analyze lib/ before compiling. The catalog is vendored into build/ by
# dart_frog build, so a stale catalog (one generated before a symbol existed)
# surfaces here as a clear "Undefined name" error rather than an opaque AOT
# "Generating AOT kernel dill failed". Only lib/ is analyzed: dart_frog's
# generated bin/server.dart trips the project's strict lints, which are not the
# concern at build time.
RUN dart analyze lib
RUN dart compile exe bin/server.dart -o bin/server

# Build a minimal serving image from the AOT-compiled `/server` and the required
# system libraries and configuration stored in `/runtime/` from the build stage.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/
# The dotprompt assets must travel with the binary and resolve relative to the
# working directory. Without this the server exits at boot with
# "A2UI prompt asset not found".
COPY --from=build /app/assets /app/assets
# The mock household database is read from `data/` at boot.
COPY --from=build /app/data /app/data
WORKDIR /app

# Start the server.
CMD ["/app/bin/server"]
