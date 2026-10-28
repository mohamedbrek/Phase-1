# Linux Security Checker

## 1. Tool Name

**Linux Security Checker**

## 2. Objective

The Linux Security Checker is a Bash script that performs some basic testing of security issues on Linux devices. The purpose of the script is to look for possible weaknesses in system accounts, file permissions, network exposure, kernel settings, software updates and security services.

This tool provides a general idea about the security settings of a system and helps identify potential weaknesses without deliberately modifying the settings.

## 3. Features

- **System Information:** Provides information about the hostname, operating system, kernel version and uptime.
- **Account Security:** Checks for extra accounts with UID 0, empty password fields, password expiration and password-less sudo.
- **File Permissions:** Verifies the permissions of important files such as `/etc/passwd`, `/etc/shadow` and `/etc/sudoers`.
- **SSH Security:** Reviews selected SSH server settings when possible.
- **Network Security:** Detects open TCP ports on all network interfaces and checks typical firewall configurations.
- **Kernel Hardening:** Reviews selected settings related to Address Space Layout Randomization (ASLR), SYN cookies and ICMP redirects.
- **Filesystem Security:** Searches the system for files with world-writable permissions and calculates the number of SUID binaries.
- **System Updates:** Checks for available package updates.
- **Security Services:** Checks the status of services such as auditd and fail2ban along with system logging.
- **Extra Hardening:** Verifies the sticky bit on the `/tmp` folder, cron file permissions, home directory access and automatic software update settings.
- **Security Summary:** Shows the number of successful checks, warnings and failures.
- **Command-Line Features:** Provides quiet mode, plain-text output, a help menu and report generation.

## 4. Requirements

- A Linux based operating system, for example, Ubuntu.
- Bash shell.
- Commonly used Linux utilities including `awk`, `grep`, `find`, `stat`, `sed` and `timeout`.
- `sudo` permission is optional when commands need administrative access.
- Additional utilities like `ss`, `sysctl` and `systemctl` can be utilized.


## 5. How to Run


### Step 1: Grant execute permission to the script


```bash
chmod +x tool.sh
```


### Step 2: Help menu will show up


```bash
./tool.sh -h
```


### Step 3: Perform security checks


```bash
sudo ./tool.sh
```


### Step 4: Executing quietly


```bash
sudo ./tool.sh -q
```


In quiet mode, only warnings and failures will be displayed without any PASS and INFO messages.

### Step 5: Run without colors

```bash
sudo ./tool.sh -n
```

### Step 6: Save a report

```bash
sudo ./tool.sh -n -o security-report.txt
```

The report is saved to the specified file in plain-text format.

## 6. Example Usage

Run the tool with administrator privileges:

```bash
sudo ./tool.sh
```

Display the available options:

```bash
./tool.sh -h
```

Generate a plain-text report:

```bash
sudo ./tool.sh -n -o security-report.txt
```

## 7. Example Output

The following is an illustrative example of the type of output produced. Actual results depend on the system being checked.

```text
security_checker v1.0

System
  [ OK ] Running as root

Accounts
  [ OK ] Only root has UID 0
  [ OK ] No empty passwords

File permissions
  [ OK ] /etc/passwd (644)
  [ OK ] /etc/group (644)

Network
  [WARN] Ports open on all interfaces
         22 8000

Kernel hardening
  [ OK ] ASLR fully enabled
  [ OK ] SYN cookies enabled

Summary
  OK 17   WARN 8   FAIL 1
  Score ------------------------ 65%
```

## Challenges Faced

- Knowing how to evaluate the security configurations of Linux through Bash commands.
- Managing tests that utilize root privileges to gain access to secure system files.
- Considering variations in services installed and tools available in different Linux distributions.
- Presenting scan results in an easily readable way by showing the warnings and failures due to the performed checks.
- Utilizing command-line options for storing scanning results.

## Future Improvements

- Include customizable importance levels of security conclusions.
- Enhance firewall identification to allow better rules evaluation.
- Expand compatibility with more Linux distributions.
- Provide possibility to print results in the JSON format.
- Provide more specific results and advice on how to fix those issues.
- Make automated tests in order to check every particular test.
- Enhance the speed of checking large filesystems.

## Screenshots

I included well-labelled screenshots of the tasks solved in the screenshots folder.


## Folder Structure
```text
Bash-Tool/
├── security_checker.sh
├── README.md
└── screenshots/
    ├── 01-main-security-scan.png
    ├── 02-final-summary.png
    ├── 03-help-mode.png
    ├── 04-test-report.png
    └── 05-quiet-mode.png
```
