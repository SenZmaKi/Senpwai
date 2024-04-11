#!/usr/bin/env bash

set -e

SENPWAI_DIR=$PREFIX/share/Senpwai
cd $SENPWAI_DIR
.venv/bin/python3 -m senpwai.senpcli "$@"
