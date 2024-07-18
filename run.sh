#!/bin/bash

action=$1
arg=$2

execute() {
  substring="#!/bin/bash"
  sha=$(curl -sSL https://api.github.com/repos/WildePizza/ollama-kubernetes/commits | jq -r '.[1].sha')
  url="https://raw.githubusercontent.com/WildePizza/ollama-kubernetes/$sha/scripts/$action.sh"
  echo "Executing: $url"
  output=$(curl -fsSL $url 2>&1)
  if [[ $output =~ $substring ]]; then
    curl -fsSL $url | bash -s $arg
  else
    sleep 1
    execute
  fi
}
execute
