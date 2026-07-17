docker buildx build --platform linux/amd64 --load -t p4-dataplane-hw .
docker run --rm -it --platform linux/amd64 --privileged -v "$PWD":/workspace p4-dataplane-hw
docker/verify-env.sh
starter/scripts/compile.sh src/dataplane.p4
starter/scripts/run_mininet.sh src/dataplane.json