
import argparse
import re
import sys

import dns.exception
import dns.resolver
import whois
from colorama import Fore, Style, init
from pyfiglet import Figlet

init(autoreset=True)

VERSION = "1.0"

RECORD_TYPES = {
    "a": "A",
    "aaaa": "AAAA",
    "cname": "CNAME",
    "mx": "MX",
    "ns": "NS",
    "txt": "TXT",
    "soa": "SOA",
}

LOOKUP_CHOICES = ["whois"] + list(RECORD_TYPES) + ["all"]

LOOKUP_DESCRIPTIONS = {
    "whois": "Domain registration details",
    "a": "IPv4 addresses",
    "aaaa": "IPv6 addresses",
    "cname": "Domain alias records",
    "mx": "Mail servers",
    "ns": "Name servers",
    "txt": "Text records",
    "soa": "Domain authority information",
    "all": "Run all lookups",
}


# These functions display messages in different colors.
def info(message):
    print(Fore.GREEN + message + Style.RESET_ALL)


def warn(message):
    print(Fore.YELLOW + message + Style.RESET_ALL)


def error(message):
    print(Fore.RED + message + Style.RESET_ALL)


def show_banner():
    print(Fore.LIGHTBLUE_EX + Figlet().renderText("DNS Recon"))
    print(f"DNS Recon Tool {VERSION}")
    print("For authorized security and educational use only.\n")


# Show the lookup options available in the tool.
def show_commands():
    print(Fore.CYAN + "\nAvailable lookup options:\n")

    for name, description in LOOKUP_DESCRIPTIONS.items():
        print(f"  {name:<8} {description}")

    print("\nExample:")
    print("  python3 dns_recon.py -d example.com -l mx")


# Check that the domain name has a valid basic format.
def valid_domain(domain):
    if not domain or len(domain) > 253:
        return False

    labels = domain.rstrip(".").split(".")

    if len(labels) < 2:
        return False

    pattern = r"^[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$"

    return all(
        re.fullmatch(pattern, label) is not None
        for label in labels
    )


# Make DNS records easier to read.
def format_record(record_type, record):
    if record_type == "MX":
        return f"Priority {record.preference} -> {record.exchange}"

    if record_type == "SOA":
        return (
            f"Primary NS: {record.mname} | "
            f"Admin: {record.rname} | "
            f"Serial: {record.serial}"
        )

    if record_type == "TXT":
        return b"".join(record.strings).decode(
            "utf-8", errors="replace"
        )

    return record.to_text()


# Look up a DNS record and display the result.
def lookup_record(domain, record_type):
    info(f"\n[{record_type}] Records for {domain}")

    try:
        answers = dns.resolver.resolve(
            domain, record_type, lifetime=5
        )

        for record in answers:
            print("  " + format_record(record_type, record))

        return True

    except dns.resolver.NXDOMAIN:
        error("  Domain does not exist.")

    except dns.resolver.NoAnswer:
        warn(f"  No {record_type} records found.")
        return True

    except dns.resolver.NoNameservers:
        error("  No nameservers could answer the query.")

    except dns.exception.Timeout:
        error("  DNS query timed out.")

    except dns.exception.DNSException as exc:
        error(f"  DNS error: {exc}")

    return False


# Try to retrieve domain registration information.
def lookup_whois(domain):
    info(f"\n[WHOIS] Information for {domain}")

    try:
        result = whois.whois(domain)

        if not result or not any(result.values()):
            warn("  No WHOIS data found.")
            return False

        for key, value in result.items():
            if value is None or value == "" or value == []:
                continue

            if isinstance(value, (list, set, tuple)):
                value = ", ".join(str(item) for item in value)

            print(f"  {key}: {value}")

        return True

    except Exception as exc:
        error(f"  WHOIS lookup failed: {exc}")
        return False


# Run the lookup selected by the user.
def run_lookup(domain, lookup):
    if lookup == "whois":
        return lookup_whois(domain)

    if lookup == "all":
        results = [lookup_whois(domain)]

        for record_type in RECORD_TYPES.values():
            results.append(lookup_record(domain, record_type))

        return all(results)

    return lookup_record(domain, RECORD_TYPES[lookup])


# Set up the arguments that can be used in the terminal.
def build_parser():
    parser = argparse.ArgumentParser(
        description="A simple DNS and WHOIS lookup tool.",
        epilog="Example: python3 dns_recon.py -d example.com -l all",
    )

    parser.add_argument(
        "-d", "--domain",
        help="Domain to investigate, e.g. example.com"
    )

    parser.add_argument(
        "-l", "--lookup",
        choices=LOOKUP_CHOICES,
        help="Type of lookup to perform"
    )

    parser.add_argument(
        "-c", "--commands",
        action="store_true",
        help="Show available lookup options"
    )

    parser.add_argument(
        "-V", "--version",
        action="version",
        version=f"%(prog)s {VERSION}"
    )

    return parser


# Start the program and handle the user's choices.
def main():
    parser = build_parser()
    args = parser.parse_args()

    if args.commands:
        show_commands()
        return 0

    if not args.domain:
        parser.error("Specify a domain with -d or --domain.")

    if not args.lookup:
        parser.error("Specify a lookup type with -l or --lookup.")

    domain = args.domain.strip().lower().rstrip(".")

    if not valid_domain(domain):
        parser.error("Enter a valid domain name, e.g. example.com.")

    show_banner()
    info(f"Domain: {domain}")
    info(f"Lookup type: {args.lookup}")

    try:
        success = run_lookup(domain, args.lookup)

    except KeyboardInterrupt:
        error("\nLookup interrupted.")
        return 130

    if success:
        info("\nLookup completed.")
        return 0

    error("\nLookup completed with errors.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
