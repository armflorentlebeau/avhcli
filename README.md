# Arm Virtual Hardware CLI tool

This tool in bash helps to quickly create/start/stop/delete Arm Virtual Hardware 3rd Party instances.

For more information: https://avh.arm.com/

## Prerequisite

curl and jq should be installed on the system, as well as the OpenVPN client and netcat to connect to the instance. To install them on Debian machines:

```
sudo apt install curl jq openvpn netcat
```

## Installation

```
git clone https://github.com/armflorentlebeau/avhcli.git
```

## Usage

```
Usage: avhcli.sh [--help | -h] [--token | -t TOKEN] [--id | -i ID] [--model | -m MODEL] OPERATION
CLI tool for Arm Virtual Hardware.
    --help  | -h         display this help and exit
    --token | -t TOKEN   specify API token
    --model | -m MODEL   specify Arm Virtual Hardware model when using create. Ignored otherwise
                         MODEL should be one of imx8mp-evk (default), rpi4b or stm32u5-b-u585i-iot02a
    --id    | -i ID      specify Arm Virtual Hardware instance ID when using start, stop or delete. Ignored otherwise
                         Instance ID can be obtained using status
    OPERATION should be one of:
    create | -c          create an Arm Virtual Hardware instance
    delete | -d          delete the Arm Virtual Hardware instance create by this script
    start  | -l          start the Arm Virtual Hardware instance created by this script
    stop   | -s          stop the Arm Virtual Hardware instance created by this script
    status | -q          query status of the Arm Virtual Hardware instances
```

## Create an API token

Log in to https://app.avh.arm.com/, go to _Profile_ > _API_ > _Generate_ and copy the token.

## Connect to an instance

When an instance is created, connection information (ip.txt and avh.ovpn) are stored where avhcli is installed.

### 1. Connect to VPN

```
sudo openvpn avh.ovpn
```

### 2. Connect to the console

```
nc $(cat ip.txt) 2000
```

