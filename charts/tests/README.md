# Run integration tests

Tests are made by two files:
1. `[chart]/templates/tests/test-[testname].yaml`
1. `tests/[chart]/values-[testname].yaml`

Before starting the test suite, a k3s cluster is created using docker.
There's no requirements for running tests locally except for helm and docker.

## Run a test for a chart

```
./run-tests.sh [chart] [testname]
```

## Run all tests for a chart

```
./run-tests.sh [chart]
```

