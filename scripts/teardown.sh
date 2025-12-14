#!/bin/bash
echo "tearing down..."
oc delete deployment,service,route,configmap,pod --all