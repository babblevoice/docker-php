# PHP Docker image

![Nightly tests](https://github.com/babblevoice/docker-php/actions/workflows/nightly.yml/badge.svg)

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

The version is plain semver, `Major.minor.bug`, and it is this image's version, not PHP's: the tag `vX.Y.Z` publishes `tinpotnick/php:X.Y.Z`. It carries on from the old numbers. Up to 0.3.8 the PHP version was written in front of ours (the tag `v7.4.33-0.3.8` published `tinpotnick/php:7.4.33-0.3.8`); the next release is `v0.3.9`, published as `tinpotnick/php:0.3.9`.

### Major

If major changes, backward compatibility is not guaranteed.

### Minor

New feature (for example additional PHP module). Every effort to maintain backward compatibility will be made.

See Dockerfile for the list of added modules.

### Bug

No new feature - bug fix update.

### Which PHP a version carries

The tag no longer says, so it is recorded in three places:

- this README: PHP 7.4.33 since 0.3.8, with the patches listed above;
- each release's notes on GitHub, where whoever cuts the release says which PHP it carries ([AGENTS.md](AGENTS.md) says how);
- the image itself. The official image it is built on sets `PHP_VERSION` in its environment, and `php -v` prints it (the patches don't change either):

```sh
docker image inspect tinpotnick/php:0.3.9 --format '{{range .Config.Env}}{{println .}}{{end}}' | grep PHP_VERSION
```

## Build

A release tag is the only thing that publishes an image. `.github/workflows/release.yml` builds it for amd64 and arm64, each on its own native runner, starts it and has php-fpm run a script, then pushes `tinpotnick/php:X.Y.Z` and nothing else: no `latest`, no `main`, no `sha-…`. [AGENTS.md](AGENTS.md) has the rules: who may tag what, the run before a pull request, and hotfixes.

```sh
git tag v0.3.9-rc.1 && git push origin v0.3.9-rc.1   # a pre-release, to try out
git tag v0.3.9 && git push origin v0.3.9             # a full release
```

To build one to try, for the platform you are on, into your local Docker and pushing nothing:

```sh
docker build -t docker-php:test .
```
