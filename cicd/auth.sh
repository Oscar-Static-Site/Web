#!/bin/bash

aws ecr get-login-password --region eu-west-2 | sudo docker login --username AWS --password-stdin 477601539816.dkr.ecr.eu-west-2.amazonaws.com
