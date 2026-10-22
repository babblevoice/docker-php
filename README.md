# PHP Docker image

Simple build for docker with additional modules from source. Examples for compose etc on usage.

## PHP 7.4 security patch

PHP 7.4 is end-of-life. From 7.4.33-0.3.8 the image recompiles the official 7.4.33 image's PHP with the PHP security team's backport for CVE-2026-109618 and CVE-2026-109619 (php2shell). The patch in `patches/` is `git format-patch -1 712e60f9` from php-src. Extensions must be built from this image (`docker-php-ext-install`), not copied in from another one, because the patch changes inline code in the Zend headers. Composer runs on the patched PHP too.

`php -v` still says 7.4.33. To tell a patched image apart, `php -i | grep max_multipart_body_parts` prints a line only when the patch is in.

The backport changes three behaviours:

- A script that runs out of `memory_limit` now ends its php-fpm worker on the spot, without running shutdown functions, destructors or session writes. nginx answers 502 instead of 500, php-fpm logs the `Allowed memory size` error and `child N exited with code 1`, and the worker is replaced straight away.
- A multipart request with more parts than `max_input_vars` + `max_file_uploads` (1,020 here) has the extra parts dropped, with a warning.
- Session upload progress no longer works, whatever `session.upload_progress.enabled` says. That is the CVE-2026-109619 path.

To drop the patch once babble_web is on a supported PHP (babble_web#1162), base the stages on that version's official image again, delete the php-patched stage and `patches/`, and update the extension directory the app stage copies from.

## Version

Build versions are tracked using semver. Major.minor.bug.

### Major

If major changes, backward compatibility is not guaranteed.

### Minor

New feature (for example additional PHP module). Every effort to maintain backward compatibility will be made.

See Dockerfile for the list of added modules.

### Bug

No new feature - bug fix update.

## Build

This will build x86 and arm. The version number is `<phpversion>-<thisbuildversion>`.

```sh
docker buildx prune
docker buildx build --platform linux/amd64,linux/arm64 -t tinpotnick/php:7.4.33-0.3.8 . --push
```
