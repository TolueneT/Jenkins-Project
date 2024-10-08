#!/bin/bash
ENV=$1
if [ "$ENV" == "staging" ]; then
    echo "Deploying to Staging..."
    # Add deployment commands here
elif [ "$ENV" == "production" ]; then
    echo "Deploying to Production..."
    # Add production deployment commands here
fi
