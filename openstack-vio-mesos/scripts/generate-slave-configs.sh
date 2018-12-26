#!/bin/bash

# Input Args: List of IP addresses separated by space.

echo "[slaves]" > ~/ansible/inventory/slaves
for slave in "$@";
do
   echo "$slave" >> ~/ansible/inventory/slaves
done
