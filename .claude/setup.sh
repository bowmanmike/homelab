#!/bin/bash
set -e

# Install Erlang/OTP runtime dependencies
if command -v apt-get &>/dev/null; then
  apt-get install -y --no-install-recommends \
    libssl-dev \
    libncurses-dev \
    2>/dev/null || sudo apt-get install -y --no-install-recommends \
    libssl-dev \
    libncurses-dev
fi

# Install mise
curl https://mise.run | sh
export PATH="$HOME/.local/bin:$PATH"
eval "$($HOME/.local/bin/mise activate bash)"

# Install Erlang/OTP 28 and Elixir 1.19.5
mise use --global erlang@28
mise use --global elixir@1.19.5-otp-28

# Install Hex and Rebar package managers
mix local.hex --force --quiet
mix local.rebar --force --quiet

# Install project dependencies
mix deps.get

# Set up the database
MIX_ENV=dev mix ecto.create --quiet
MIX_ENV=dev mix ecto.migrate --quiet
