# Coveralls CircleCI Orb [![CircleCI](https://circleci.com/gh/coverallsapp/orb.svg?style=svg)](https://circleci.com/gh/coverallsapp/orb) [![CircleCI Orb Version](https://img.shields.io/badge/endpoint.svg?url=https://badges.circleci.io/orb/coveralls/coveralls)](https://circleci.com/orbs/registry/orb/coveralls/coveralls)

## How to enable

**Note ⚠️:** To use CircleCI Orbs in your projects, you need to enable two settings:

- from organization settings allow using uncertified orbs `Settings -> Security -> Allow uncertified orbs`
- from the project's settings allow beta features `Settings -> Advanced Settings -> Enable pipelines`

See the official [CircleCI documentation](https://circleci.com/docs/2.0/using-orbs/).

## Commands

* `coveralls/upload`

See the parameter documentation here:
https://circleci.com/orbs/registry/orb/coveralls/coveralls#commands

## Supported coverage formats

See [**coverage-reporter**](https://github.com/coverallsapp/coverage-reporter#supported-coverage-report-formats)

## Examples

Each example below should be placed into `circle.yml` or `.circleci/config.yml` file.

Also see our [demo project](https://github.com/coverallsapp/coveralls-node-demo) with the setup.

### Simple

Build and upload to Coveralls in a single job.
Demo: https://github.com/coverallsapp/coveralls-node-demo

```yaml
version: 2.1

orbs:
  coveralls: coveralls/coveralls@x.y.z

jobs:
  build:
    docker:
      - image: circleci/node:10.0.0

    steps:
      - checkout

      - run:
          name: Install and Make
          command: 'npm install && make test-coverage'

      - coveralls/upload
```

### Parallel

Coveralls parallel build.
'build' jobs uploads coverage, then 'done' job hits parallel complete webhook to finish the build.
Demo: https://github.com/coverallsapp/coveralls-node-demo

```yaml
version: 2.1

orbs:
  coveralls: coveralls/coveralls@x.y.z

jobs:
  build-1:
    docker:
      - image: circleci/node:10.0.0

    steps:
      - checkout

      - run:
          name: Install and Make 1
          command: 'npm install && make test-coverage-1'

      - coveralls/upload:
          parallel: true
          flag_name: Test 1

  build-2:
    docker:
      - image: circleci/node:10.0.0

    steps:
      - checkout

      - run:
          name: Install and Make 2
          command: 'npm install && make test-coverage-2'

      - coveralls/upload:
          parallel: true
          flag_name: Test 2

  done:
    docker:
      - image: circleci/node:10.0.0

    steps:
      - coveralls/upload:
          parallel_finished: true

workflows:
  test_parallel_then_upload:
    jobs:
      - build-1
      - build-2
      - done:
          requires: [build-1, build-2]
```

## Dev Notes

* Validate:

```bash
circleci orb pack ./src > orb.yml

circleci orb validate orb.yml
```

* Publish:

Auto-publish with pushing a git tag:

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```

## License

This project is licensed under the terms of the [MIT license](/LICENSE).
