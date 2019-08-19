FROM buildpack-deps:buster

# Run container build script
COPY build.sh /opt/build.sh
RUN /opt/build.sh && rm /opt/build.sh

ENV DEBIAN_FRONTEND=noninteractive

# Use unicode
ENV LANG=C.UTF-8

# Ruby

ENV RUBY_MAJOR 2.6
ENV RUBY_VERSION 2.6.3
ENV RUBY_DOWNLOAD_SHA256 11a83f85c03d3f0fc9b8a9b6cad1b2674f26c5aaa43ba858d4b0fcc2b54171e1

ENV GEM_HOME /usr/local/bundle
ENV BUNDLE_PATH "$GEM_HOME"
ENV BUNDLE_SILENCE_ROOT_WARNING 1
ENV BUNDLE_APP_CONFIG "$GEM_HOME"
# path recommendation: https://github.com/bundler/bundler/pull/6469#issuecomment-383235438
ENV PATH "$GEM_HOME/bin:$BUNDLE_PATH/gems/bin:$PATH"

# Rust

ENV RUSTUP_HOME /usr/local/rustup
ENV CARGO_HOME /usr/local/cargo
ENV PATH "/usr/local/cargo/bin:$PATH"
ENV RUST_VERSION nightly-2019-07-08

# Node.js

ENV NODE_VERSION 12.8.0
ENV YARN_VERSION 1.17.3

# clang

ENV LLVM_PKG_VERSION 9
ENV CC clang

USER artichoke

CMD ["/bin/bash"]
