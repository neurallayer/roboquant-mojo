import io
import urllib.request
import zipfile
from pathlib import Path


def download_ecb():
    """Download the latest ECB exchange rates."""
    url = "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-hist.zip"
    with urllib.request.urlopen(url, timeout=10) as response:
        content = response.read()
    with zipfile.ZipFile(io.BytesIO(content)) as z:
        p = Path.home() / ".roboquant"
        z.extractall(p)

def main():
    download_ecb()
    print("Downloaded ECB exchange rates to ~/.roboquant")

if __name__ == "__main__":
    main()