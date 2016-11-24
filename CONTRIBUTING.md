# Contributors guide

## Bug Reports

Please [open an issue][new-issue].

The more detailed your report, the faster it can be resolved. Once the
bug has been resolved, the person responsible will tag the issue as
_needs confirmation_ and assign the issue back to you. Once you have
tested and confirmed that the issue is resolved, close the issue. If
you are not a member of the project, you will be asked for
confirmation and we will close it.

[new-issue]: https://github.com/tweag/sparkle/issues/new

## Code

If you would like to contribute code to fix a bug, add a new feature,
or otherwise improve sparkle, [pull requests][pull-requests] are most
welcome. It's a good idea to [submit an issue][new-issue] to discuss
the change before plowing into writing code.

Please include a [changelog][changelog] entry and full Haddock
documentation updates with your pull request.

[changelog]: https://github.com/tweag/sparkle/blob/master/CHANGELOG.md
[pull-requests]: https://help.github.com/articles/about-pull-requests/

## Continuous integration

Every time a pull request is updated, the [Wercker][wercker] service
runs continuous integration checks inside a Docker build container.
A declarative specification of the [build image][docker-build-img] is
[here][dockerfile]. By design, the build image is *not* rebuilt at
every new code push, because there is no way to use Docker registries
as a cache for the result of building the Dockerfile to avoiding
rebuilding the image all the time. This is because registries don't
record what the build inputs for an image were.

If you change the `Dockerfile` or any of its dependencies, you should
[publish][docker-push] a new version of the image. It will be used as
the environment for subsequent CI checks.

[docker-build-img]: https://hub.docker.com/r/tweag/sparkle/
[wercker]: http://www.wercker.com/
[dockerfile]: https://github.com/tweag/sparkle/blob/master/Dockerfile
[docker-push]: https://github.com/tweag/sparkle/blob/master/Dockerfile
