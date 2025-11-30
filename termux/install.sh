#!/usr/bin/env bash

set -e

echo -e "\033[0;32mUpdating pkg\033[0m"
pkg update -y

echo -e "\033[0;32mInstalling python\033[0m"
pkg install python -y

echo -e "\033[0;32mInstalling git\033[0m"
pkg install git -y

SENPWAI_DIR=$PREFIX/share/Senpwai
echo -e "\033[0;32mCloning repository to $SENPWAI_DIR\033[0m"
rm -rf $SENPWAI_DIR
git clone https://github.com/SenZmaKi/Senpwai --depth 1 $SENPWAI_DIR
cd $SENPWAI_DIR

echo -e "\033[0;32mCreating virtual environment, this may take a while\033[0m"
python3 -m venv .venv

echo -e "\033[0;32mActivating virtual environment\033[0m"
source .venv/bin/activate

echo -e "\033[0;32mInstalling python-cryptography\033[0m"
apt download python-cryptography
dpkg -x python-cryptography_* $PREFIX/tmp
mv $PREFIX/tmp${PREFIX}/lib/python3.12/site-packages/* .venv/lib/python3.12/site-packages

echo -e "\033[0;32mInstalling dependencies\033[0m"
pip install -r termux/requirements.txt

SENPCLI_SH_PATH=$SENPWAI_DIR/termux/senpcli.sh
SENPCLI_BIN_PATH=$PREFIX/bin/senpcli
echo -e "\033[0;32mSetting up senpcli\033[0m"
chmod +x $SENPCLI_SH_PATH
mv $SENPCLI_SH_PATH $SENPCLI_BIN_PATH

echo ""
echo -e "\033[0;32mInstallation complete\033[0m"
echo -e "\033[0;32mRun \"senpcli --help\" for help\033[0m"
