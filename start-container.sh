#!/bin/bash

echo ""

echo -e "\nrun strom-nimbus  contianer\n"
sudo docker run -itd  -p 9088:8080  -p 6627:6627 -p 3181:2181  --restart=always --name strom-nimbus --hostname strom-nimbus lenny/strom:2.1 &> /dev/null

echo ""
