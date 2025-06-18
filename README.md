# oSSH

This project provides a Bash script to set up an SSH server over Tor. It allows users to securely connect to their server using SSH while maintaining anonymity through Tor. This project is inspired from [this](https://github.com/juhanurmi/stealth-ssh/) repo.

## Prerequisites

Before running the script, make sure that you have the following installed on your system:

- `ssh`
- `tor`

## Usage

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/nrz-21/oSSH
   cd oSSH
   ```

2. **Run the Script**:
   ```bash
   sudo ./main.sh --create
   ```

## Important

It is advised to go over the script or any script before running it so that you know what it is doing. And If you, for some reason want to setup multiple SSH servers it can be done just look at the comments.
