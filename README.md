# Go Install Script

A simple, automated shell script to install, update, and configure the [Go programming language](https://go.dev/) on Linux.

## Features

- **Automatic Version Detection**: Fetches the latest stable Go version from the official API.
- **Smart Updates**: Checks your installed version and only prompts for an update if a newer version is available.
- **Disk Space Check**: Ensures you have enough space before downloading.
- **Architecture Support**: Automatically detects your system architecture (amd64, arm64, etc.).
- **Automatic PATH Configuration**:
    - Detects your shell (`bash` or `zsh`).
    - Appends the necessary `export PATH` line to your profile (`.bashrc` or `.zshrc`).
    - **Shell Reload**: Offers to reload your shell session immediately so you can use Go right away.

## Usage

1.  Make the script executable:
    ```bash
    chmod +x go-get.sh
    ```

2.  Run the script:
    ```bash
    ./go-get.sh
    ```

3.  Follow the on-screen prompts.

## Requirements

- Linux OS
- `curl`, `tar`, and `sudo` privileges.
