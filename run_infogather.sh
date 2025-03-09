#!/bin/bash

# Set working directory
WORK_DIR="/app"
cd $WORK_DIR

# Create time stamp variable for archiving
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
echo "Current task timestamp: $TIMESTAMP"

# Create output directory for this scan
OUTPUT_DIR="$WORK_DIR/scans/$TIMESTAMP"
mkdir -p "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/crawler_output"
mkdir -p "$WORK_DIR/dict"

# Create log file
LOG_FILE="$OUTPUT_DIR/scan.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Starting information gathering task, time: $(date)"
echo "All files will be saved to: $OUTPUT_DIR"

# Ensure we have the required dictionary files
if [ ! -f "$WORK_DIR/dict/dns-Jhaddix.txt" ]; then
  echo "Downloading dns-Jhaddix.txt dictionary file..."
  wget https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/DNS/dns-Jhaddix.txt -O "$WORK_DIR/dict/dns-Jhaddix.txt"
fi

if [ ! -f "$WORK_DIR/dict/bug-bounty-program-subdomains-trickest-inventory.txt" ]; then
  echo "Downloading bug-bounty-program-subdomains-trickest-inventory.txt dictionary file..."
  wget https://raw.githubusercontent.com/trickest/wordlists/main/bug-bounty-program-subdomains-trickest-inventory.txt -O "$WORK_DIR/dict/bug-bounty-program-subdomains-trickest-inventory.txt"
fi

# Copy target domain file to output directory for record keeping
if [ -f "$WORK_DIR/rootdomains.txt" ]; then
  cp "$WORK_DIR/rootdomains.txt" "$OUTPUT_DIR/"
else
  echo "Error: rootdomains.txt file does not exist. Please create this file and list target domains."
  exit 1
fi

# DNSX: List all root domains and output to dnsx.txt
echo "Running dnsx..."
dnsx -l "$OUTPUT_DIR/rootdomains.txt" -o "$OUTPUT_DIR/dnsx.txt"

# Subfinder: Discover subdomains from dnsx.txt and output to subdomains.txt
echo "Running subfinder..."
subfinder -dL "$OUTPUT_DIR/dnsx.txt" -o "$OUTPUT_DIR/subdomains.txt" -stats -all

# PureDNS: Brute force subdomains using two different wordlists, append results to subdomains.txt
echo "Running PureDNS brute force..."
puredns bruteforce "$WORK_DIR/dict/dns-Jhaddix.txt" -d "$OUTPUT_DIR/rootdomains.txt" -t 500 >> "$OUTPUT_DIR/subdomains.txt"
puredns bruteforce "$WORK_DIR/dict/bug-bounty-program-subdomains-trickest-inventory.txt" -t 500 -d "$OUTPUT_DIR/rootdomains.txt" >> "$OUTPUT_DIR/subdomains.txt"

# Use PureDNS to resolve subdomains and save results to sub_resolved.txt
echo "Resolving subdomains..."
puredns resolve "$OUTPUT_DIR/subdomains.txt" -t 500 | sort -u > "$OUTPUT_DIR/sub_resolved.txt"

# Add back Naabu port scanning portion
echo "Running Naabu port scanning..."
cat "$OUTPUT_DIR/sub_resolved.txt" "$OUTPUT_DIR/dnsx.txt" | naabu -p - -exclude-ports 80,443,21,22,25 -rate 20000 -c 500 -retries 2 -warm-up-time 1 -silent > "$OUTPUT_DIR/naabu.txt"

# Use httpx to check if resolved subdomains are active
echo "Checking active subdomains..."
if [ -f "$WORK_DIR/ips.txt" ]; then
    cat "$OUTPUT_DIR/naabu.txt" "$WORK_DIR/ips.txt" "$OUTPUT_DIR/sub_resolved.txt" | httpx -t 50 -rl 1500 -silent > "$OUTPUT_DIR/sub_alive.txt"
else
    cat "$OUTPUT_DIR/naabu.txt" "$OUTPUT_DIR/sub_resolved.txt" | httpx -t 50 -rl 1500 -silent > "$OUTPUT_DIR/sub_alive.txt"
fi

# Create params.txt file (if it doesn't exist) for crawlergo to use
if [ ! -f "$OUTPUT_DIR/params.txt" ]; then
    touch "$OUTPUT_DIR/params.txt"
fi

# Run crawlergo crawler - use correct path
echo "Running crawlergo crawler..."
cd "$OUTPUT_DIR" # Temporarily switch working directory to ensure crawlergo outputs to correct location
$WORK_DIR/crawlergogo -tf sub_alive.txt -rf rootdomains.txt -cgo /root/go/bin/crawlergo -c /usr/bin/chromium-browser -pf params.txt
cd "$WORK_DIR" # Switch back to working directory

# Use Katana to gather additional information such as robots.txt and sitemap.xml
echo "Running Katana..."
cat "$OUTPUT_DIR/sub_alive.txt" | katana -sc -kf robotstxt,sitemapxml -jc -c 50 -passive > "$OUTPUT_DIR/katana_out.txt"

# Use Hakrawler to enumerate subdomains and collect links
echo "Running Hakrawler..."
cat "$OUTPUT_DIR/sub_alive.txt" | hakrawler -subs -t 50 > "$OUTPUT_DIR/hakrawler_out.txt"

# Use waybackurls instead of gau
echo "Running waybackurls..."
cat "$OUTPUT_DIR/sub_alive.txt" | waybackurls > "$OUTPUT_DIR/waybackurls_out.txt"

# Merge outputs and process URLs
echo "Merging and processing URLs..."
cat "$OUTPUT_DIR/katana_out.txt" "$OUTPUT_DIR/hakrawler_out.txt" "$OUTPUT_DIR/waybackurls_out.txt" > "$OUTPUT_DIR/urls.txt"

# Switch to output directory to run pureurls.py
cd "$OUTPUT_DIR"
python3 $WORK_DIR/pureurls.py
cd "$WORK_DIR"

# Find URLs in urless that aren't in crawlergo, continue crawling with crawlergo
echo "Filtering URLs and continuing to crawl..."
cd "$OUTPUT_DIR"
cat pureurls.txt | urless -fk m4ra7h0n -khw -kym > urless.txt
cat crawler_output/* | urless -fk m4ra7h0n -khw -kym > crawler.txt
python3 $WORK_DIR/crawlergodata.py
$WORK_DIR/crawlergogo -tf crawler_continue.txt -rf rootdomains.txt -cgo /root/go/bin/crawlergo -c /usr/bin/chromium-browser -pf params.txt
rm -rf urless.txt crawler.txt crawler_continue.txt urls.txt
cd "$WORK_DIR"

# Save results (maximize results as much as possible)
echo "Saving final results..."
cat "$OUTPUT_DIR/crawler_output/"* | sort -u | anew "$OUTPUT_DIR/pur