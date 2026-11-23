# PHP Docker image

Simple build for docker with additional modules from source. Examples for compose etc on usage.

## PHP 7.4 security patches

PHP 7.4 is end-of-life, so the image recompiles the official 7.4.33 image's PHP with the security fixes in `patches/`, applied in file-name order:

- From 7.4.33-0.3.8, CVE-2026-109618 and CVE-2026-109619 (php2shell): the PHP security team's own 7.4 backport, `git format-patch -1 712e60f9` from php-src.
- From 7.4.33-0.3.9, CVE-2026-126714: a session file is emptied before every write, so a write that is cut short can no longer leave part of the previous session behind for PHP to unserialise. Upstream fixed it in PHP 8.2.36 (php-src 41c0941a) and published no 7.4 fix; the patch is that commit cherry-picked onto 7.4.33, unaltered apart from its context.

Extensions must be built from this image (`docker-php-ext-install`), not copied in from another one, because the php2shell patch changes inline code in the Zend headers. Composer runs on the patched PHP too.

`php -v` still says 7.4.33. To tell a patched image apart, `php -i | grep max_multipart_body_parts` prints a line only when the php2shell patch is in. The build fails without the CVE-2026-126714 fix: its last step cuts a session write short and checks that nothing of the old session is left.

The php2shell backport changes three behaviours:

- A script that runs out of `memory_limit` now ends its php-fpm worker on the spot, without running shutdown functions, destructors or session writes. nginx answers 502 instead of 500, php-fpm logs the `Allowed memory size` error and `child N exited with code 1`, and the worker is replaced straight away.
- A multipart request with more parts than `max_input_vars` + `max_file_uploads` (1,020 here) has the extra parts dropped, with a warning.
- Session upload progress no longer works, whatever `session.upload_progress.enabled` says. That is the CVE-2026-109619 path.

The CVE-2026-126714 backport changes one: if PHP cannot empty a session file before writing it, the write fails with an `ftruncate() failed` warning instead of going ahead. A write that is cut short still loses that request's session changes, but no longer leaves two sessions mixed in one file.

To drop the patches once babble_web is on a supported PHP (babble_web#1162), base the stages on that version's official image again, delete the php-patched stage, `patches/` and the CVE-2026-126714 check at the end of the Dockerfile, and update the extension directory the app stage copies from.

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
docker buildx build --platform linux/amd64,linux/arm64 -t tinpotnick/php:7.4.33-0.3.9 . --push
```
