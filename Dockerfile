FROM ubuntu:22.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Set working directory
WORKDIR /app

# Install basic dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    git \
    python3 \
    python3-pip \
    unzip \
    gcc \
    make \
    chromium-browser \
    libpcap-dev \
    build-essential \
    dnsutils \
    iputils-ping \
    chromium-driver \
    golang \
    && rm -rf /var/lib/apt/lists/*

# Set Go environment
ENV GOPATH=/root/go
ENV PATH=$PATH:/usr/local/go/bin:$GOPATH/bin

# Install Go tools
RUN go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest && \
    go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest && \
    go install -v github.com/d3mondev/puredns/v2@latest && \
    go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest && \
    go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest && \
    go install -v github.com/projectdiscovery/katana/cmd/katana@latest && \
    go install -v github.com/hakluke/hakrawler@latest && \
    go install -v github.com/tomnomnom/waybackurls@latest && \
    go install -v github.com/ameenmaali/urless@latest && \
    go install -v github.com/tomnomnom/anew@latest && \
    go install -v github.com/tomnomnom/unfurl@latest

# Install massdns (required by puredns)
RUN git clone https://github.com/blechschmidt/massdns.git && \
    cd massdns && \
    make && \
    make install && \
    cd .. && \
    rm -rf massdns

# Install crawlergo
RUN go install -v github.com/Qianlitp/crawlergo@latest

# Setup Python utilities
RUN pip3 install --no-cache-dir requests bs4 lxml

# Create necessary directories
RUN mkdir -p /app/dict && \
    mkdir -p /app/scans

# Download dictionaries
RUN wget https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/DNS/dns-Jhaddix.txt -O /app/dict/dns-Jhaddix.txt && \
    wget https://raw.githubusercontent.com/trickest/wordlists/main/bug-bounty-program-subdomains-trickest-inventory.txt -O /app/dict/bug-bounty-program-subdomains-trickest-inventory.txt

# Copy custom scripts
COPY pureurls.py /app/
COPY crawlergogo /app/
COPY crawlergodata.py /app/

# Create a example root domains file
RUN echo "example.com" > /app/rootdomains.txt

# Add volume for persistent data
VOLUME ["/app/scans"]

# Create entry point script
COPY entrypoint.sh /app/
RUN chmod +x /app/entrypoint.sh

# Set entry point
ENTRYPOINT ["/app/entrypoint.sh"]