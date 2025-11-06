#!/bin/bash
cmake -S . -B build # To configure the cmake project
cmake --build build --parallel # To build the project
