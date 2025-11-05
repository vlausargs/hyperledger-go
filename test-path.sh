#!/bin/bash
export PATH=$PATH:$HOME/.local/share/fabric-samples/bin
echo "PATH: $PATH"
which cryptogen
if command -v cryptogen &> /dev/null; then
    echo "cryptogen found"
else
    echo "cryptogen not found"
fi
