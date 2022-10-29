
# PHP Docker image

Simple build for docker with additional modules from source. Examples for compose etc on usage.

# Version

Build versions are tracked using semver. Major.minor.bug.

## Major

If major changes backward compatible is not garanteed.

## Minor

New feature (for example additional PHP module). Every effort to maintain backwards compatability will be made.

See Dockerfile for the list of added modules.

## Bug

No new feture - bug fix update.

# Build

This will build x86 and arm. The version number is <phpversion>-<thisbuildversion>

```
docker buildx prune
docker buildx build --platform linux/amd64,linux/arm64 -t tinpotnick/php:7.4.30-0.3.2 . --push
```
