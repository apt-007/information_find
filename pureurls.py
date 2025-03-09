#!/usr/bin/env python3
# Simple URL processing script

import re
import os

def clean_urls(input_file="urls.txt", output_file="pureurls.txt"):
    if not os.path.exists(input_file):
        print(f"Error: {input_file} does not exist")
        return
        
    with open(input_file, 'r') as f:
        urls = f.readlines()
    
    # Remove duplicates
    urls = list(set(urls))
    
    # Filter and clean URLs
    clean = []
    for url in urls:
        url = url.strip()
        if url and not re.search(r'\.(jpg|jpeg|gif|css|tif|tiff|png|ttf|woff|woff2|ico|pdf|svg|txt|js)(\?|$)', url, re.IGNORECASE):
            clean.append(url)
    
    # Save to output file
    with open(output_file, 'w') as f:
        for url in clean:
            f.write(f"{url}\n")
    
    print(f"Processed {len(urls)} URLs, saved {len(clean)} clean URLs to {output_file}")

if __name__ == "__main__":
    clean_urls()