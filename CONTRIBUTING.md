# Contributing to Artichoke

👋 Hi and welcome to [Artichoke](https://github.com/artichoke). Thanks for
taking the time to contribute! 💪💎🙌

artichoke-ci is infrasturcture for CI pipelines for
[Artichoke Ruby](https://github.com/artichoke/artichoke).
[There is lots to do](https://github.com/artichoke/artichoke/issues).

If the Artichoke does not run Ruby source code in the same way that MRI does, it
is a bug and we would appreciate if you
[filed an issue so we can fix it](https://github.com/artichoke/artichoke/issues/new).

If you would like to contribute code 👩‍💻👨‍💻, find an issue that looks interesting
and leave a comment that you're beginning to investigate. If there is no issue,
please file one before beginning to work on a PR.

## Discussion

If you'd like to engage in a discussion outside of GitHub, you can
[join Artichoke's public Discord server](https://discord.gg/QCe2tp2).

## Setup

Building this image requires [Docker](https://www.docker.com/).

artichoke-ci includes Ruby, Shell, and Text sources. Developing on artichoke-ci
requires configuring several dependencies, which are orchestrated by
[Yarn](https://yarnpkg.com/).

### Node.js

artichoke-ci uses Yarn and Node.js for linting and orchestration.

You will need to install
[Node.js](https://nodejs.org/en/download/package-manager/) and
[Yarn](https://yarnpkg.com/en/docs/install).

On macOS, you can install Node.js and Yarn with
[Homebrew](https://docs.brew.sh/Installation):

```shell
brew install node yarn
```

### Node.js Packages

Once you have Yarn installed, you can install the packages specified in
[`package.json`](/package.json) by running:

```shell
yarn install
```

You can check to see that this worked by running `yarn lint` and observing no
errors.

### Ruby

artichoke-ci requires a recent Ruby 2.x and [bundler](https://bundler.io/) 2.x.
The [`.ruby-version`](/.ruby-version) file in the root of Artichoke specifies
Ruby 2.6.3.

If you use [RVM](https://rvm.io/), you can install Ruby dependencies by running:

```shell
rvm install "$(cat .ruby-version)"
gem install bundler
```

If you use [rbenv](https://github.com/rbenv/rbenv) and
[ruby-build](https://github.com/rbenv/ruby-build), you can install Ruby
dependencies by running:

```shell
rbenv install "$(cat .ruby-version)"
gem install bundler
rbenv rehash
```

To lint Ruby sources, artichoke-ci uses
[RuboCop](https://github.com/rubocop-hq/rubocop). `yarn lint` installs RuboCop
and all other gems automatically.

### Shell

artichoke-ci uses [shfmt](https://github.com/mvdan/sh) for formatting and
[shellcheck](https://github.com/koalaman/shellcheck) for linting Shell scripts.

On macOS, you can install shfmt and shellcheck with
[Homebrew](https://docs.brew.sh/Installation):

```shell
brew install shfmt shellcheck
```

## Code Quality

### Linting

Once you [configure a development environment](#setup), run the following to
lint sources:

```shell
yarn lint
```

Merges will be blocked by CI if there are lint errors.

## Code Analysis

### Source Code Statistics

To view statistics about the source code in the Artichoke Site, you can run
`yarn loc`, which depends on [loc](https://github.com/cgag/loc). You can install
loc by running:

```shell
cargo install loc
```
