#!/bin/bash

#
# Copyright DataStax, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -ex
this_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
chart=${1:-""}
filter_tests=${2:-""}

if [ -z "$chart" ]; then
    echo "usage: run-tests.sh [chart]"
    exit 1
fi


source $this_dir/k3s.sh
k3s_stop
k3s_start

print_pods_logs() {
    local namespace=$1
    within_k3s kubectl get pods -n $namespace | tail -n +2 | awk '{print $1}' | while read pod; do 
        echo "DESCRIBE POD: $pod" 
        within_k3s kubectl describe pod/$pod -n $namespace
        echo "LOGS FOR POD: $pod"
        within_k3s kubectl logs $pod -n $namespace
    done
}

for f in charts/$chart/templates/tests/*; do
    basename_test=$(basename $f)
    if [[ "$basename_test" != "test-"* ]]; then
        echo "skipping $basename_test file"
        continue
    fi
    if [[ "$basename_test" != *"$filter_tests"* ]]; then
        echo "skipping $basename_test test"
        continue
    fi

    values_file=${this_dir}/${chart}/values-${basename_test:5}
    if [ ! -f "$values_file" ]; then
        echo "values file not found for test $basename_test, expected values file at $values_file"
        exit 1
    fi
    release_name=${basename_test//\.yaml}
    namespace=$release_name
    echo "==========================================="
    echo "starting test $release_name"
    within_k3s kubectl delete namespace $namespace 2> /dev/null || echo ""
    within_k3s kubectl create namespace $namespace
    within_k3s helm install -n $namespace $release_name charts/$chart -f $values_file

    timeout="5m" # the first time it downloads the images so it might take time 

    within_k3s kubectl get deployments -n $release_name | tail -n +2 | awk '{print $1}' | while read deployment; do 
        within_k3s kubectl wait deployment -n $release_name $deployment --for condition=Available=True --timeout=$timeout || (
            echo "test $release_name failed, deployment $deployment not ready" && 
            print_pods_logs $release_name &&
            within_k3s kubectl delete namespace $release_name &&
            k3s_stop &&
            exit 1
        )
    done
    within_k3s kubectl get statefulset -n $release_name | tail -n +2 | awk '{print $1}' | while read sts; do 
        within_k3s kubectl wait statefulset -n $release_name $sts --for condition=Available=True --timeout=$timeout || (
            echo "test $release_name failed, statefulset $sts not ready" && 
            print_pods_logs $release_name &&
            within_k3s kubectl delete namespace $release_name &&
            k3s_stop &&
            exit 1
        )
    done

    within_k3s helm test -n $release_name $release_name --filter "name=$release_name" || (
        echo "test $release_name failed" && 
        print_pods_logs $release_name &&
        within_k3s kubectl delete namespace $release_name &&
        k3s_stop &&
        exit 1
    )
    within_k3s helm delete $release_name -n $release_name
    within_k3s kubectl delete namespace $release_name
    echo "test $release_name passed"
    echo "==========================================="
done
k3s_stop
