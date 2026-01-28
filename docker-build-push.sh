#!/usr/bin/env bash
DOCKER_BUILDKIT=1 docker build -t llm-docoder:latest docker
docker login --username=白沟新城布壳儿网络工作室 registry.cn-beijing.aliyuncs.com
docker tag llm-docoder:latest registry.cn-beijing.aliyuncs.com/buukle-library/llm-docoder:latest
docker push registry.cn-beijing.aliyuncs.com/buukle-library/llm-docoder:latest
