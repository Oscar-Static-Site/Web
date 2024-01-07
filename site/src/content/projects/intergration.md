---
title: "Using github actions for Continuous Integration"
date: 2024-01-07T13:13 
draft: false
---


# Using GitHub actions to lint and test the go code.
All the code can be find in the following [repo](https://github.com/oscar-todo-app/todo-app) in the infra cluster folder. 

Since we are building an app to maintain code quality is a good idea to continously test and lint the code.

Since the tests are build around testcontainers and we will have a db everytime we run go test creating a github action is quite straight forward.

``` yaml
name: Run go test.

on:
  push:
    paths:
      - ./src/**
  pull_request:
    branches: ["main"]
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Go
        uses: actions/setup-go@v4
        with:
          cache-dependency-path: |
            src/go.sum
          go-version: "1.21"
      - name: Test
        run: cd ./src; go test -v ./cmd
  lint:
    name: lint
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: read
      checks: write
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-go@v4
        with:
          go-version: "1.21"
          cache: false
      - name: golangci-lint
        uses: golangci/golangci-lint-action@v3
        with:
          version: v1.54
          working-directory: src
```

