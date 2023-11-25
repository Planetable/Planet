import socket
import crayons

def check_connection(address, port):
    try:
        with socket.create_connection((address, port), timeout=10):
            print(crayons.green(f"Connection successful: {address} {port}"))
    except socket.error as err:
        print(crayons.red(f"Error connecting to {address} {port} - {err}"))

def main():
    filename = "peers.txt"  # Updated file name
    with open(filename, "r") as file:
        for line in file:
            line = line.strip()
            # Skip lines starting with #
            if line.startswith('#') or line == '':
                print(line)
                continue
            parts = line.split()  # Splits by whitespace
            address = parts[0]
            port = int(parts[1])
            check_connection(address, port)

if __name__ == "__main__":
    main()
