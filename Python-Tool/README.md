# DNS Lookup Tool

## 1. Tool Name
DNS Lookup Tool

## 2. Objective
I created the DNS Lookup Tool as a basic Python program to enhance my skills in cybersecurity coding. It allows me to search for DNS records as well as obtain domain registration data via the command-line interface.

## 3. Features
- Retrieves A records (IPv4).
- Retrieves AAAA records (IPv6).
- Retrieves MX records (for mail).
- Retrieves NS, CNAME, TXT, and SOA records.
- Obtains domain whois information (registration details).
- Allows to execute all the functions with only one command.
- Performs validations of domain names.
- Deals with the most common DNS errors and wrong inputs.
- Offers command-line parameters and help system.
- Outputs the results in human-readable form.

## 4. Requirements
- Python version 3
- `dnspython` library
- `python-whois` package
- `colorama` module
- `pyfiglet` tool

## 5. How to Run

### Step 1: Activate the virtual environment

From the Python-Tool directory, run:

```bash
source .venv/bin/activate
```

### Step 2: Install the required libraries

If the libraries are not already installed, run:

```bash
python -m pip install dnspython python-whois colorama pyfiglet
```

### Step 3: Run the tool

Use the following command format:

```bash
python dns_recon.py -d <domain> -l <lookup_type>
```

Replace `<domain>` with the domain you want to investigate and `<lookup_type>` with the type of lookup you want to perform.

## 6. Example Usage

Display the help menu:

```bash
python dns_recon.py --help
```

Look up IPv4 addresses:

```bash
python dns_recon.py -d google.com -l a
```

Look up mail servers:

```bash
python dns_recon.py -d google.com -l mx
```

Retrieve domain registration information:

```bash
python dns_recon.py -d google.com -l whois
```

Run all available lookups:

```bash
python dns_recon.py -d google.com -l all
```

Display the available lookup options:

```bash
python dns_recon.py -c
```

## 7. Example Output

Example command:

```bash
python dns_recon.py -d google.com -l mx
```

Example result:

```text
DNS Recon Tool 1.0
Domain: google.com
Lookup type: mx

[MX] Records for google.com
  Priority 10 -> smtp.google.com.

Lookup completed.
```

DNS results may change over time.

## 8. Challenges Faced
- Installing Python libraries in Ubuntu due to the externally managed environment limitations.
- Creating a virtual environment to ensure safe installation of dependencies.
- Dealing with DNS errors and checking the validity of domain names.
- Learning how different types of DNS records operate.

## 10. Future Improvements

I want to enhance this instrument in several ways in the future. Some of the features I would like to add are the following: 

- The ability to store results of queries in a file, either TXT or JSON
- Better detection of DNS resolves errors and delays
- Better input validation and better error messages
- Comparing and contrasting DNS results of different queries
- An improved format of the report to make the reading of results easier 
- Testing of major functions

## Screenshots

I included well-labelled screenshots of the tasks solved in the screenshots folder.

## Repository Structure
```text
Python-Tool/
├── dns_recon.py
├── README.md
└── screenshots/
    ├── 01-help-option.png
    ├── 02-ipv4-lookup.png
    ├── 03-invalid-domain.png
    ├── 04-mx-lookup.png
    └── 05-missing-arguments.png
```
