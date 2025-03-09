#!/usr/bin/env python3
# Process crawler data for continuing crawling

import os

def find_new_urls():
    # Read urless.txt
    with open('urless.txt', 'r') as f:
        urless_urls = set(line.strip() for line in f)
    
    # Read crawler.txt
    with open('crawler.txt', 'r') as f:
        crawler_urls = set(line.strip() for line in f)
    
    # Find URLs in urless but not in crawler
    new_urls = urless_urls - crawler_urls
    
    # Write to crawler_continue.txt
    with open('crawler_continue.txt', 'w') as f:
        for url in new_urls:
            f.write(f"{url}\n")
    
    print(f"Found {len(new_urls)} new URLs to continue crawling")

if __name__ == "__main__":
    find_new_urls()