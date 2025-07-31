set dotenv-load
set dotenv-filename := x"${GITHUB_ENV:-.env.build}"

export NAME := "squashfuse"
export REPO := env_var_or_default("REPO", "vasi/squashfuse")
export VERSION := env_var_or_default("VERSION", "1.0.0")
export CHECKOUT_URL := env_var_or_default("CHECKOUT_URL", "https://github.com/" + REPO + ".git")
export CHECKOUT_DEPTH := env_var_or_default("CHECKOUT_DEPTH", "1")
export CHECKOUT_REF := env_var_or_default("CHECKOUT_REF", "main")
export TARGET_OS := env_var_or_default("TARGET_OS", os())
export TARGET_ARCH := env_var_or_default("TARGET_ARCH", arch())
export ENV_FILE := env_var_or_default("GITHUB_ENV", justfile_directory() / ".env.build")
export WORK_DIR := justfile_directory()
export BUILD_DIR := WORK_DIR / "build"
export DIST_DIR := WORK_DIR/ "dist"
export DIST_NAME := NAME + "-" + VERSION + "-" + TARGET_OS + "-" + TARGET_ARCH

version:
  @gh release list -L 1 -R {{REPO}} --json tagName -q '.[0].tagName' | cat

env:
  #!/usr/bin/env sh
  cd {{justfile_directory()}}
  rm -f {{ENV_FILE}}

  export VERSION="$(just version)"
  export RELEASE_NAME="$VERSION"
  export RELEASED=$(gh release view $RELEASE_NAME > /dev/null 2>&1 && echo true || echo false)

  echo "NAME={{NAME}}" >> {{ENV_FILE}}
  echo "REPO={{REPO}}" >> {{ENV_FILE}}
  echo "VERSION=$VERSION" >> {{ENV_FILE}}
  echo "CHECKOUT_URL={{CHECKOUT_URL}}" >> {{ENV_FILE}}
  echo "CHECKOUT_DEPTH={{CHECKOUT_DEPTH}}" >> {{ENV_FILE}}
  echo "CHECKOUT_REF=$VERSION" >> {{ENV_FILE}}
  echo "TARGET_OS={{TARGET_OS}}" >> {{ENV_FILE}}
  echo "TARGET_ARCH={{TARGET_ARCH}}" >> {{ENV_FILE}}
  echo "RELEASE_NAME=$RELEASE_NAME" >> {{ENV_FILE}}
  echo "RELEASED=$RELEASED" >> {{ENV_FILE}}
  cat {{ENV_FILE}}

install:
  sudo apt install -y gcc make pkg-config libfuse3-dev \
    zlib1g-dev liblzo2-dev liblzma-dev liblz4-dev libzstd-dev \
    automake autoconf libtool \
    fuse3 fio squashfs-tools

checkout:
  git clone --depth {{CHECKOUT_DEPTH}} -b {{CHECKOUT_REF}} {{CHECKOUT_URL}} {{BUILD_DIR}}


compile:
  echo "$(nproc) threads compile"
  cd {{BUILD_DIR}} && ./autogen.sh
  cd {{BUILD_DIR}} && ./configure CFLAGS="-static"
  cd {{BUILD_DIR}} && make LDFLAGS="-all-static" -j$(nproc)

package:
  rm -rf {{DIST_DIR}}
  mkdir {{DIST_DIR}}
  cd {{BUILD_DIR}} && cp squashfuse squashfuse_extract squashfuse_ll squashfuse_ls {{DIST_DIR}}
  cd {{DIST_DIR}} && tar -zcvf {{WORK_DIR}}/{{DIST_NAME}}.tar.gz .
  mv {{WORK_DIR}}/{{DIST_NAME}}.tar.gz {{DIST_DIR}}

pipe:
  just checkout
  just compile
  just package

clean:
  rm -rf {{ENV_FILE}}
  rm -rf {{BUILD_DIR}}
  rm -rf {{DIST_DIR}}